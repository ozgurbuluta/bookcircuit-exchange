import { Trade, TradeItem, Profile, Book } from './types';
import { db, auth } from './firebase';
import {
  collection,
  doc,
  addDoc,
  getDoc,
  getDocs,
  updateDoc,
  query,
  where,
  orderBy,
  serverTimestamp,
  writeBatch,
} from 'firebase/firestore';
import { getProfileById } from './profileService';
import { getBookById } from './bookService';

// Helper to convert Firestore document to Trade
const docToTrade = async (docSnap: any): Promise<Trade> => {
  const data = docSnap.data ? docSnap.data() : docSnap;
  const id = docSnap.id || data.id;

  // Fetch initiator and recipient profiles
  const [initiator, recipient] = await Promise.all([
    data.initiatorId ? getProfileById(data.initiatorId) : null,
    data.recipientId ? getProfileById(data.recipientId) : null,
  ]);

  // Fetch trade items
  const itemsSnapshot = await getDocs(collection(db, 'trades', id, 'tradeItems'));
  const items: TradeItem[] = await Promise.all(
    itemsSnapshot.docs.map(async (itemDoc) => {
      const itemData = itemDoc.data();
      const book = itemData.bookId ? await getBookById(itemData.bookId) : undefined;

      return {
        id: itemDoc.id,
        trade_id: id,
        book_id: itemData.bookId,
        owner_id: itemData.ownerId,
        recipient_id: itemData.recipientId,
        item_type: itemData.itemType || 'book',
        interest_id: itemData.interestId,
        created_at: itemData.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
        book: book || undefined,
      };
    })
  );

  return {
    id,
    initiator_id: data.initiatorId,
    recipient_id: data.recipientId,
    status: data.status,
    initiator_message: data.initiatorMessage,
    recipient_message: data.recipientMessage,
    is_direct_request: data.isDirectRequest || false,
    is_counteroffered: data.isCounteroffered || false,
    created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updated_at: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    initiator: initiator || undefined,
    recipient: recipient || undefined,
    items,
  };
};

// Get user's trades
export const getUserTrades = async (statusFilter?: string): Promise<Trade[]> => {
  try {
    const user = auth.currentUser;
    if (!user) return [];

    // Get trades where user is initiator
    const initiatorQuery = query(
      collection(db, 'trades'),
      where('initiatorId', '==', user.uid),
      orderBy('createdAt', 'desc')
    );

    // Get trades where user is recipient
    const recipientQuery = query(
      collection(db, 'trades'),
      where('recipientId', '==', user.uid),
      orderBy('createdAt', 'desc')
    );

    const [initiatorSnapshot, recipientSnapshot] = await Promise.all([
      getDocs(initiatorQuery),
      getDocs(recipientQuery),
    ]);

    // Combine and deduplicate
    const tradeMap = new Map<string, any>();

    for (const doc of initiatorSnapshot.docs) {
      tradeMap.set(doc.id, doc);
    }

    for (const doc of recipientSnapshot.docs) {
      if (!tradeMap.has(doc.id)) {
        tradeMap.set(doc.id, doc);
      }
    }

    // Convert to Trade objects
    let trades = await Promise.all(
      Array.from(tradeMap.values()).map(doc => docToTrade(doc))
    );

    // Apply status filter if provided
    if (statusFilter) {
      trades = trades.filter(trade => trade.status === statusFilter);
    }

    // Sort by date
    trades.sort((a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    );

    return trades;
  } catch (error) {
    console.error('Error getting user trades:', error);
    return [];
  }
};

// Get trade by ID
export const getTradeById = async (tradeId: string): Promise<Trade | null> => {
  try {
    const docSnap = await getDoc(doc(db, 'trades', tradeId));

    if (!docSnap.exists()) {
      return null;
    }

    return await docToTrade(docSnap);
  } catch (error) {
    console.error('Error getting trade:', error);
    return null;
  }
};

// Create a new trade
export const createTrade = async (
  partnerId: string,
  myBookIds: string[],
  theirBookIds: string[],
  message?: string
): Promise<{ success: boolean; tradeId?: string; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    const batch = writeBatch(db);

    // Create trade document
    const tradeRef = doc(collection(db, 'trades'));
    const tradeData = {
      initiatorId: user.uid,
      recipientId: partnerId,
      status: 'pending',
      initiatorMessage: message || '',
      recipientMessage: '',
      isDirectRequest: theirBookIds.length === 1 && myBookIds.length === 0,
      isCounteroffered: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    batch.set(tradeRef, tradeData);

    // Add trade items for my books (I'm offering)
    for (const bookId of myBookIds) {
      const itemRef = doc(collection(db, 'trades', tradeRef.id, 'tradeItems'));
      batch.set(itemRef, {
        bookId,
        ownerId: user.uid,
        recipientId: partnerId,
        itemType: 'book',
        createdAt: serverTimestamp(),
      });
    }

    // Add trade items for their books (I want)
    for (const bookId of theirBookIds) {
      const itemRef = doc(collection(db, 'trades', tradeRef.id, 'tradeItems'));
      batch.set(itemRef, {
        bookId,
        ownerId: partnerId,
        recipientId: user.uid,
        itemType: 'book',
        createdAt: serverTimestamp(),
      });
    }

    // Create notification for recipient
    const notificationRef = doc(collection(db, 'notifications'));
    batch.set(notificationRef, {
      userId: partnerId,
      type: 'trade_request',
      message: 'You have a new trade request',
      relatedId: tradeRef.id,
      read: false,
      createdAt: serverTimestamp(),
    });

    await batch.commit();

    return { success: true, tradeId: tradeRef.id };
  } catch (error) {
    console.error('Error creating trade:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Update trade status
export const updateTradeStatus = async (
  tradeId: string,
  newStatus: 'accepted' | 'rejected' | 'completed' | 'cancelled',
  message?: string
): Promise<{ success: boolean; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    const tradeDoc = await getDoc(doc(db, 'trades', tradeId));
    if (!tradeDoc.exists()) {
      return { success: false, error: 'Trade not found' };
    }

    const tradeData = tradeDoc.data();

    // Verify user is a participant
    if (tradeData.initiatorId !== user.uid && tradeData.recipientId !== user.uid) {
      return { success: false, error: 'Not authorized' };
    }

    const updateData: any = {
      status: newStatus,
      updatedAt: serverTimestamp(),
    };

    if (message) {
      if (user.uid === tradeData.recipientId) {
        updateData.recipientMessage = message;
      } else {
        updateData.initiatorMessage = message;
      }
    }

    await updateDoc(doc(db, 'trades', tradeId), updateData);

    // Create notification for the other party
    const otherUserId = user.uid === tradeData.initiatorId
      ? tradeData.recipientId
      : tradeData.initiatorId;

    await addDoc(collection(db, 'notifications'), {
      userId: otherUserId,
      type: 'trade_update',
      message: `Trade ${newStatus}`,
      relatedId: tradeId,
      read: false,
      createdAt: serverTimestamp(),
    });

    // Add to trade history
    await addDoc(collection(db, 'tradeHistory'), {
      tradeId,
      action: newStatus,
      actorId: user.uid,
      details: message || '',
      createdAt: serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error('Error updating trade status:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Get pending trades count
export const getPendingTradesCount = async (): Promise<number> => {
  try {
    const user = auth.currentUser;
    if (!user) return 0;

    const q = query(
      collection(db, 'trades'),
      where('recipientId', '==', user.uid),
      where('status', '==', 'pending')
    );

    const snapshot = await getDocs(q);
    return snapshot.size;
  } catch (error) {
    console.error('Error getting pending trades count:', error);
    return 0;
  }
};
