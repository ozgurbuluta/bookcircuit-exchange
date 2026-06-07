import { Profile } from './types';
import { db, auth } from './firebase';
import {
  doc,
  getDoc,
  getDocs,
  updateDoc,
  serverTimestamp,
  collection,
  query,
  where,
  documentId,
} from 'firebase/firestore';

// Helper to convert Firestore document to Profile
const docToProfile = (docSnap: any): Profile => {
  const data = docSnap.data ? docSnap.data() : docSnap;
  const id = docSnap.id || data.id;

  return {
    id,
    full_name: data.fullName || '',
    avatar_url: data.avatarUrl || '',
    email: data.email || '',
    bio: data.bio || '',
    website: data.website || '',
    university: data.university || '',
    location_city: data.locationCity || '',
    location_state: data.locationState || '',
    location_country: data.locationCountry || '',
    location_lat: data.locationLat,
    location_lng: data.locationLng,
    created_at: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    updated_at: data.updatedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
  };
};

// Get profile by user ID
export const getProfileById = async (userId: string): Promise<Profile | null> => {
  try {
    const docSnap = await getDoc(doc(db, 'users', userId));

    if (!docSnap.exists()) {
      return null;
    }

    return docToProfile(docSnap);
  } catch (error) {
    console.error('Error getting profile:', error);
    return null;
  }
};

// Get current user's profile
export const getCurrentProfile = async (): Promise<Profile | null> => {
  const user = auth.currentUser;
  if (!user) return null;
  return getProfileById(user.uid);
};

// Get multiple profiles by user IDs
export const getProfilesByIds = async (userIds: string[]): Promise<Record<string, Profile>> => {
  try {
    if (userIds.length === 0) return {};

    // Firestore limits 'in' queries to 30 items
    const profileMap: Record<string, Profile> = {};
    const chunks = [];
    for (let i = 0; i < userIds.length; i += 30) {
      chunks.push(userIds.slice(i, i + 30));
    }

    for (const chunk of chunks) {
      const q = query(
        collection(db, 'users'),
        where(documentId(), 'in', chunk)
      );
      const snapshot = await getDocs(q);
      snapshot.docs.forEach(docSnap => {
        profileMap[docSnap.id] = docToProfile(docSnap);
      });
    }

    return profileMap;
  } catch (error) {
    console.error('Error getting profiles:', error);
    return {};
  }
};

// Update profile
export const updateProfile = async (
  userId: string,
  profileData: Partial<{
    full_name: string;
    bio: string;
    website: string;
    university: string;
    avatar_url: string;
    location_city: string;
    location_state: string;
    location_country: string;
    location_lat: number;
    location_lng: number;
  }>
): Promise<{ success: boolean; error?: string; profile?: Profile }> => {
  try {
    const updateData: any = {
      updatedAt: serverTimestamp(),
    };

    if (profileData.full_name !== undefined) updateData.fullName = profileData.full_name;
    if (profileData.bio !== undefined) updateData.bio = profileData.bio;
    if (profileData.website !== undefined) updateData.website = profileData.website;
    if (profileData.university !== undefined) updateData.university = profileData.university;
    if (profileData.avatar_url !== undefined) updateData.avatarUrl = profileData.avatar_url;
    if (profileData.location_city !== undefined) updateData.locationCity = profileData.location_city;
    if (profileData.location_state !== undefined) updateData.locationState = profileData.location_state;
    if (profileData.location_country !== undefined) updateData.locationCountry = profileData.location_country;
    if (profileData.location_lat !== undefined) updateData.locationLat = profileData.location_lat;
    if (profileData.location_lng !== undefined) updateData.locationLng = profileData.location_lng;

    await updateDoc(doc(db, 'users', userId), updateData);

    const updatedProfile = await getProfileById(userId);

    return { success: true, profile: updatedProfile || undefined };
  } catch (error) {
    console.error('Error updating profile:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
};
