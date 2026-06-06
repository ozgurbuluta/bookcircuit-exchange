import { Conversation, Message, Profile } from './types';
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
  limit,
  serverTimestamp,
  onSnapshot,
  Unsubscribe,
} from 'firebase/firestore';
import { getProfileById } from './profileService';

// Helper to convert Firestore document to Conversation
const docToConversation = async (docSnap: any, currentUserId: string): Promise<Conversation> => {
  const data = docSnap.data ? docSnap.data() : docSnap;
  const id = docSnap.id || data.id;

  // Find the other participant
  const otherUserId = data.participantIds?.find((pid: string) => pid !== currentUserId);
  const otherUser = otherUserId ? await getProfileById(otherUserId) : undefined;

  // Get participants
  const participantsSnapshot = await getDocs(collection(db, 'conversations', id, 'participants'));
  const participants = participantsSnapshot.docs.map(doc => ({
    user_id: doc.data().userId,
    conversation_id: id,
    created_at: doc.data().createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
  }));

  // Get unread count for current user
  const currentParticipant = participantsSnapshot.docs.find(
    doc => doc.data().userId === currentUserId
  );
  const unreadCount = currentParticipant?.data()?.unreadCount || 0;

  return {
    id,
    created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updated_at: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    last_message: data.lastMessage,
    last_message_at: data.lastMessageAt?.toDate?.()?.toISOString(),
    unread_count: unreadCount,
    participants,
    other_user: otherUser || undefined,
  };
};

// Get user's conversations
export const getUserConversations = async (): Promise<Conversation[]> => {
  try {
    const user = auth.currentUser;
    if (!user) return [];

    const q = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', user.uid),
      orderBy('lastMessageAt', 'desc')
    );

    const snapshot = await getDocs(q);

    const conversations = await Promise.all(
      snapshot.docs.map(doc => docToConversation(doc, user.uid))
    );

    return conversations;
  } catch (error) {
    console.error('Error getting conversations:', error);
    return [];
  }
};

// Get conversation by ID
export const getConversationById = async (conversationId: string): Promise<Conversation | null> => {
  try {
    const user = auth.currentUser;
    if (!user) return null;

    const docSnap = await getDoc(doc(db, 'conversations', conversationId));

    if (!docSnap.exists()) {
      return null;
    }

    return await docToConversation(docSnap, user.uid);
  } catch (error) {
    console.error('Error getting conversation:', error);
    return null;
  }
};

// Get or create conversation with a user
export const getOrCreateConversation = async (
  otherUserId: string,
  bookId?: string
): Promise<{ success: boolean; conversationId?: string; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    // Check for existing conversation
    const q = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', user.uid)
    );

    const snapshot = await getDocs(q);

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.participantIds?.includes(otherUserId)) {
        return { success: true, conversationId: doc.id };
      }
    }

    // Create new conversation
    const conversationRef = await addDoc(collection(db, 'conversations'), {
      participantIds: [user.uid, otherUserId],
      bookId: bookId || null,
      lastMessage: null,
      lastMessageAt: serverTimestamp(),
      lastMessageSenderId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    // Add participants subcollection
    await addDoc(collection(db, 'conversations', conversationRef.id, 'participants'), {
      userId: user.uid,
      unreadCount: 0,
      createdAt: serverTimestamp(),
    });

    await addDoc(collection(db, 'conversations', conversationRef.id, 'participants'), {
      userId: otherUserId,
      unreadCount: 0,
      createdAt: serverTimestamp(),
    });

    return { success: true, conversationId: conversationRef.id };
  } catch (error) {
    console.error('Error getting/creating conversation:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Get messages for a conversation
export const getMessages = async (
  conversationId: string,
  limitCount: number = 50
): Promise<Message[]> => {
  try {
    const q = query(
      collection(db, 'conversations', conversationId, 'messages'),
      orderBy('createdAt', 'desc'),
      limit(limitCount)
    );

    const snapshot = await getDocs(q);

    const messages = await Promise.all(
      snapshot.docs.map(async (docSnap) => {
        const data = docSnap.data();
        const userProfile = data.userId ? await getProfileById(data.userId) : undefined;

        return {
          id: docSnap.id,
          conversation_id: conversationId,
          user_id: data.userId,
          content: data.content,
          created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
          updated_at: data.updatedAt?.toDate?.()?.toISOString(),
          user: userProfile || undefined,
          related_book_id: data.relatedBookId,
        };
      })
    );

    // Return in chronological order
    return messages.reverse();
  } catch (error) {
    console.error('Error getting messages:', error);
    return [];
  }
};

// Send a message
export const sendMessage = async (
  conversationId: string,
  content: string,
  relatedBookId?: string
): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    // Add message to subcollection
    const messageRef = await addDoc(
      collection(db, 'conversations', conversationId, 'messages'),
      {
        userId: user.uid,
        content,
        relatedBookId: relatedBookId || null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }
    );

    // Update conversation with last message
    await updateDoc(doc(db, 'conversations', conversationId), {
      lastMessage: content,
      lastMessageAt: serverTimestamp(),
      lastMessageSenderId: user.uid,
      updatedAt: serverTimestamp(),
    });

    // Update unread count for other participant
    const convDoc = await getDoc(doc(db, 'conversations', conversationId));
    if (convDoc.exists()) {
      const participantIds = convDoc.data().participantIds || [];
      const otherUserId = participantIds.find((id: string) => id !== user.uid);

      if (otherUserId) {
        const participantsSnapshot = await getDocs(
          collection(db, 'conversations', conversationId, 'participants')
        );

        for (const participantDoc of participantsSnapshot.docs) {
          if (participantDoc.data().userId === otherUserId) {
            const currentCount = participantDoc.data().unreadCount || 0;
            await updateDoc(participantDoc.ref, {
              unreadCount: currentCount + 1,
            });
            break;
          }
        }
      }
    }

    return { success: true, messageId: messageRef.id };
  } catch (error) {
    console.error('Error sending message:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};

// Mark conversation as read
export const markConversationAsRead = async (conversationId: string): Promise<void> => {
  try {
    const user = auth.currentUser;
    if (!user) return;

    const participantsSnapshot = await getDocs(
      collection(db, 'conversations', conversationId, 'participants')
    );

    for (const participantDoc of participantsSnapshot.docs) {
      if (participantDoc.data().userId === user.uid) {
        await updateDoc(participantDoc.ref, { unreadCount: 0 });
        break;
      }
    }
  } catch (error) {
    console.error('Error marking conversation as read:', error);
  }
};

// Subscribe to messages (real-time)
export const subscribeToMessages = (
  conversationId: string,
  onMessagesUpdate: (messages: Message[]) => void
): Unsubscribe => {
  const q = query(
    collection(db, 'conversations', conversationId, 'messages'),
    orderBy('createdAt', 'asc')
  );

  return onSnapshot(q, async (snapshot) => {
    const messages = await Promise.all(
      snapshot.docs.map(async (docSnap) => {
        const data = docSnap.data();
        const userProfile = data.userId ? await getProfileById(data.userId) : undefined;

        return {
          id: docSnap.id,
          conversation_id: conversationId,
          user_id: data.userId,
          content: data.content,
          created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
          updated_at: data.updatedAt?.toDate?.()?.toISOString(),
          user: userProfile || undefined,
          related_book_id: data.relatedBookId,
        };
      })
    );

    onMessagesUpdate(messages);
  });
};

// Get unread messages count
export const getUnreadMessagesCount = async (): Promise<number> => {
  try {
    const user = auth.currentUser;
    if (!user) return 0;

    const q = query(
      collection(db, 'conversations'),
      where('participantIds', 'array-contains', user.uid)
    );

    const snapshot = await getDocs(q);
    let totalUnread = 0;

    for (const convDoc of snapshot.docs) {
      const participantsSnapshot = await getDocs(
        collection(db, 'conversations', convDoc.id, 'participants')
      );

      for (const participantDoc of participantsSnapshot.docs) {
        if (participantDoc.data().userId === user.uid) {
          totalUnread += participantDoc.data().unreadCount || 0;
          break;
        }
      }
    }

    return totalUnread;
  } catch (error) {
    console.error('Error getting unread count:', error);
    return 0;
  }
};
