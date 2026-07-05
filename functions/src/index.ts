/**
 * Turtle Turning Pages — server-side economy jobs (decision D1 "hybrid").
 *
 * The client TradeEngine owns interactive transitions; these functions cover
 * what a client cannot be trusted or relied upon to do:
 *  - expirySweep: day-6 warnings + day-7 auto-expiry with refunds (spec §4.9)
 *  - swapReminderSweep: D7 nudges at +12h/+24h while a swap sits half-confirmed
 *  - pushFanout: FCM push for every notification document created
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

initializeApp();
const db = getFirestore();

const POINTS_PRICE = 50;
const EXPIRY_DAYS = 7;
const WARNING_DAYS = 6;

function daysAgo(days: number): Timestamp {
  return Timestamp.fromMillis(Date.now() - days * 24 * 60 * 60 * 1000);
}

function hoursAgo(hours: number): Timestamp {
  return Timestamp.fromMillis(Date.now() - hours * 60 * 60 * 1000);
}

async function notify(userId: string, type: string, refId: string) {
  await db.collection("notifications").add({
    userId,
    type,
    refId,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ---------------------------------------------------------------------------
// Expiry sweep (spec §4.9) — hourly
// ---------------------------------------------------------------------------
export const expirySweep = onSchedule("every 60 minutes", async () => {
  // Day-7: expire + refund
  const stale = await db
    .collection("trades")
    .where("status", "==", "requested")
    .where("requestedAt", "<", daysAgo(EXPIRY_DAYS))
    .limit(100)
    .get();

  for (const doc of stale.docs) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      const trade = snap.data();
      if (!trade || trade.status !== "requested") return;

      if (trade.escrowed === true) {
        const requesterRef = db.collection("users").doc(trade.requesterId);
        const requester = await tx.get(requesterRef);
        tx.update(requesterRef, {
          points: ((requester.data()?.points as number) ?? 0) + POINTS_PRICE,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      tx.update(doc.ref, {
        status: "expired",
        escrowed: false,
        closedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(db.collection("books").doc(trade.bookId), {
        requestCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const trade = doc.data();
    await notify(trade.requesterId, "expired_refunded", doc.id);
    logger.info(`expired trade ${doc.id}`);
  }

  // Day-6: warn the owner once
  const warnable = await db
    .collection("trades")
    .where("status", "==", "requested")
    .where("requestedAt", "<", daysAgo(WARNING_DAYS))
    .limit(100)
    .get();

  for (const doc of warnable.docs) {
    const trade = doc.data();
    if (trade.expiryWarned === true) continue;
    await doc.ref.update({ expiryWarned: true });
    await notify(trade.ownerId, "expiry_warning", doc.id);
    logger.info(`expiry warning for trade ${doc.id}`);
  }
});

// ---------------------------------------------------------------------------
// Swap-confirmation reminders (decision D7) — hourly: +12h and +24h nudges
// ---------------------------------------------------------------------------
export const swapReminderSweep = onSchedule("every 60 minutes", async () => {
  const halfConfirmed = await db
    .collection("trades")
    .where("status", "==", "accepted")
    .where("firstConfirmAt", "<", hoursAgo(12))
    .limit(100)
    .get();

  for (const doc of halfConfirmed.docs) {
    const trade = doc.data();
    const confirmedBy: string[] = trade.swapConfirmedBy ?? [];
    if (confirmedBy.length !== 1) continue;

    const awaiting =
      confirmedBy[0] === trade.requesterId ? trade.ownerId : trade.requesterId;

    const firstConfirmAt = trade.firstConfirmAt as Timestamp;
    const hoursSince =
      (Date.now() - firstConfirmAt.toMillis()) / (60 * 60 * 1000);

    if (hoursSince >= 24 && trade.reminder24Sent !== true) {
      await doc.ref.update({ reminder24Sent: true });
      await notify(awaiting, "marked_swapped", doc.id);
      logger.info(`24h swap reminder for trade ${doc.id}`);
    } else if (
      hoursSince >= 12 &&
      hoursSince < 24 &&
      trade.reminder12Sent !== true
    ) {
      await doc.ref.update({ reminder12Sent: true });
      await notify(awaiting, "marked_swapped", doc.id);
      logger.info(`12h swap reminder for trade ${doc.id}`);
    }
  }
});

// ---------------------------------------------------------------------------
// Push fan-out — every notification doc becomes an FCM push (decision D12)
// ---------------------------------------------------------------------------
const PUSH_COPY: Record<string, { title: string; body: string }> = {
  request_received: {
    title: "A neighbor wants a book of yours",
    body: "Accept, decline, or say hello in chat.",
  },
  request_accepted: {
    title: "Your request was accepted",
    body: "Agree on a spot over chat and swap hand to hand.",
  },
  request_declined: {
    title: "Your request was declined",
    body: `Your ${POINTS_PRICE} pts are back on your balance.`,
  },
  trade_cancelled: {
    title: "A trade was cancelled",
    body: "Any held points went straight back.",
  },
  expiry_warning: {
    title: "A request expires tomorrow",
    body: "Accept or decline before it goes quiet.",
  },
  expired_refunded: {
    title: "A request expired",
    body: `+${POINTS_PRICE} pts returned to your balance.`,
  },
  marked_swapped: {
    title: "Confirm your swap",
    body: "Your neighbor marked the trade as swapped — confirm when it is done.",
  },
  rating_received: {
    title: "You received a rating",
    body: "See it on your shelf.",
  },
  new_book_nearby: {
    title: "A new book appeared nearby",
    body: "Something fresh within walking distance.",
  },
  journal_event: {
    title: "New in the club journal",
    body: "A story, list, or meetup from the club.",
  },
};

export const pushFanout = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userSnap = await db.collection("users").doc(data.userId).get();
    const token = userSnap.data()?.fcmToken as string | undefined;
    if (!token) return;

    const copy = PUSH_COPY[data.type] ?? {
      title: "Turtle Turning Pages",
      body: "Something moved on your shelf.",
    };

    try {
      await getMessaging().send({
        token,
        notification: copy,
        data: {
          type: String(data.type),
          refId: String(data.refId ?? ""),
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
    } catch (error) {
      logger.warn(`push failed for user ${data.userId}`, error);
    }
  }
);
