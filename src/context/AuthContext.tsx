import React, { createContext, useState, useEffect, useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  User,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  sendPasswordResetEmail
} from 'firebase/auth';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import { toast } from "@/components/ui/use-toast";
import { Profile } from '@/lib/types';

interface AuthContextProps {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signUp: (email: string, password: string, fullName?: string) => Promise<{ success: boolean; data?: any; error?: any }>;
  signIn: (email: string, password: string) => Promise<{ success: boolean; data?: any; error?: any }>;
  signOut: () => Promise<{ success: boolean; error?: any }>;
  resetPassword: (email: string) => Promise<{ success: boolean; error?: any }>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextProps | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // Fetch user profile from Firestore
  const fetchProfile = async (userId: string): Promise<Profile | null> => {
    console.log(`[AuthContext] Fetching profile for user: ${userId}`);
    try {
      const profileRef = doc(db, 'users', userId);
      const profileSnap = await getDoc(profileRef);

      if (profileSnap.exists()) {
        const data = profileSnap.data();
        console.log('[AuthContext] Profile found:', data);
        return {
          id: profileSnap.id,
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
        } as Profile;
      } else {
        console.log('[AuthContext] Profile not found, will create default');
        return null;
      }
    } catch (error: any) {
      console.error('[AuthContext] Error fetching profile:', error.message);
      return null;
    }
  };

  // Create a default profile for a new user
  const createDefaultProfile = async (userId: string, email: string, fullName?: string): Promise<Profile | null> => {
    console.log(`[AuthContext] Creating default profile for user: ${userId}`);
    try {
      const profileRef = doc(db, 'users', userId);
      const profileData = {
        id: userId,
        email: email,
        fullName: fullName || '',
        avatarUrl: '',
        bio: '',
        website: '',
        university: '',
        locationCity: '',
        locationState: '',
        locationCountry: '',
        locationLat: null,
        locationLng: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      await setDoc(profileRef, profileData);
      console.log('[AuthContext] Default profile created');

      return {
        id: userId,
        full_name: fullName || '',
        avatar_url: '',
        email: email,
        bio: '',
        website: '',
        university: '',
        location_city: '',
        location_state: '',
        location_country: '',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      } as Profile;
    } catch (error: any) {
      console.error('[AuthContext] Error creating default profile:', error.message);
      return null;
    }
  };

  // Refresh the user's profile data
  const refreshProfile = async () => {
    console.log('[AuthContext] refreshProfile called');
    if (user) {
      const profileData = await fetchProfile(user.uid);
      if (profileData) {
        setProfile(profileData);
      }
    }
  };

  // Listen to auth state changes
  useEffect(() => {
    let mounted = true;
    console.log('[AuthContext] Setting up auth state listener');

    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      console.log('[AuthContext] Auth state changed:', firebaseUser?.uid);

      if (!mounted) return;

      if (firebaseUser) {
        setUser(firebaseUser);

        // Fetch or create profile
        let profileData = await fetchProfile(firebaseUser.uid);
        if (!profileData) {
          profileData = await createDefaultProfile(firebaseUser.uid, firebaseUser.email || '');
        }

        if (mounted) {
          setProfile(profileData);
        }
      } else {
        setUser(null);
        setProfile(null);
      }

      if (mounted) {
        setLoading(false);
      }
    });

    return () => {
      mounted = false;
      unsubscribe();
    };
  }, []);

  // Sign up with email and password
  const signUp = async (email: string, password: string, fullName?: string) => {
    try {
      setLoading(true);
      const userCredential = await createUserWithEmailAndPassword(auth, email, password);

      // Create profile in Firestore
      await createDefaultProfile(userCredential.user.uid, email, fullName);

      toast({
        title: "Account created!",
        description: "Welcome to Turtle Turning Pages.",
      });

      navigate('/dashboard');
      return { success: true, data: userCredential };
    } catch (error: any) {
      console.error("Error signing up:", error.message);

      let errorMessage = error.message;
      if (error.code === 'auth/email-already-in-use') {
        errorMessage = 'An account with this email already exists.';
      } else if (error.code === 'auth/weak-password') {
        errorMessage = 'Password should be at least 6 characters.';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      }

      toast({
        title: "Sign up failed",
        description: errorMessage,
        variant: "destructive"
      });
      return { success: false, error: errorMessage };
    } finally {
      setLoading(false);
    }
  };

  // Sign in with email and password
  const signIn = async (email: string, password: string) => {
    try {
      setLoading(true);
      const userCredential = await signInWithEmailAndPassword(auth, email, password);

      toast({
        title: "Welcome back!",
        description: `Signed in as ${email}`,
      });

      navigate('/dashboard');
      return { success: true, data: userCredential };
    } catch (error: any) {
      console.error("Error signing in:", error.message);

      let errorMessage = error.message;
      if (error.code === 'auth/user-not-found') {
        errorMessage = 'No account found with this email.';
      } else if (error.code === 'auth/wrong-password') {
        errorMessage = 'Incorrect password.';
      } else if (error.code === 'auth/invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (error.code === 'auth/too-many-requests') {
        errorMessage = 'Too many failed attempts. Please try again later.';
      }

      toast({
        title: "Sign in failed",
        description: errorMessage,
        variant: "destructive"
      });
      return { success: false, error: errorMessage };
    } finally {
      setLoading(false);
    }
  };

  // Sign out
  const signOut = async () => {
    try {
      setLoading(true);
      await firebaseSignOut(auth);

      setUser(null);
      setProfile(null);

      toast({
        title: "Signed out",
        description: "You have been signed out successfully",
      });

      navigate('/');
      return { success: true };
    } catch (error: any) {
      console.error("Error signing out:", error.message);
      toast({
        title: "Sign out failed",
        description: error.message,
        variant: "destructive"
      });
      return { success: false, error: error.message };
    } finally {
      setLoading(false);
    }
  };

  // Reset password
  const resetPassword = async (email: string) => {
    try {
      await sendPasswordResetEmail(auth, email);
      toast({
        title: "Password reset email sent",
        description: "Check your inbox for the reset link.",
      });
      return { success: true };
    } catch (error: any) {
      console.error("Error resetting password:", error.message);

      let errorMessage = error.message;
      if (error.code === 'auth/user-not-found') {
        errorMessage = 'No account found with this email.';
      }

      toast({
        title: "Password reset failed",
        description: errorMessage,
        variant: "destructive"
      });
      return { success: false, error: errorMessage };
    }
  };

  const value = {
    user,
    profile,
    loading,
    signUp,
    signIn,
    signOut,
    resetPassword,
    refreshProfile,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
