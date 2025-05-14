import React, { createContext, useState, useEffect, useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, profileClient } from '@/lib/supabase';
import { Session, User } from '@supabase/supabase-js';
import { toast } from "@/components/ui/use-toast";
import { Profile } from '@/lib/types';

// Track active AbortControllers
const activeFetchControllers: Map<string, AbortController> = new Map();

interface AuthContextProps {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signUp: (email: string, password: string) => Promise<{ success: boolean; data?: any; error?: any }>;
  signIn: (email: string, password: string) => Promise<{ success: boolean; data?: any; error?: any }>;
  signOut: () => Promise<{ success: boolean; error?: any }>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextProps | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<any | null>(null);
  const navigate = useNavigate();

  // Fetch user profile from the database
  const fetchProfile = async (userId: string) => {
    console.log(`[AuthContext] Starting fetchProfile for user: ${userId}`);
    
    // Abort previous fetch for this user if any
    if (activeFetchControllers.has(userId)) {
      console.log(`[AuthContext] Aborting previous fetch for user: ${userId}`);
      activeFetchControllers.get(userId)?.abort();
      activeFetchControllers.delete(userId);
    }
    
    // Create a new AbortController for this fetch
    const controller = new AbortController();
    activeFetchControllers.set(userId, controller);
    const { signal } = controller;
    
    try {
      // Use the profileClient with shorter timeout and pass the signal
      const { data, error } = await profileClient
        .from('profiles')
        // Correct the select statement to match the actual schema
        .select('id, full_name, bio, location, website, avatar_url, created_at, updated_at') 
        .eq('id', userId)
        .abortSignal(signal) // Pass signal here
        .single();
      
      // Check if the request was aborted after the await
      if (signal.aborted) {
        console.log(`[AuthContext] Fetch aborted for user ${userId} AFTER await.`);
        return null; // Or handle as needed
      }
      
      console.log(`[AuthContext] fetchProfile response for user: ${userId}`, { data, error });
      if (error) {
        // Don't log aborted errors as actual errors
        if (error.message.includes('aborted')) {
          console.log(`[AuthContext] Fetch explicitly aborted for user ${userId}.`);
          return null;
        }
        console.error(`[AuthContext] Error fetching profile for ${userId}:`, error.message);
        if (error.code === 'PGRST116') {
          console.log('[AuthContext] Profile not found, creating default profile for:', userId);
          // Pass signal to createDefaultProfile as well
          return await createDefaultProfile(userId, signal);
        }
        return null;
      }

      console.log('[AuthContext] Fetched profile data for:', userId);
      return data as Profile;
    } catch (error: any) {
      if (error.name === 'AbortError' || error.message.includes('aborted')) {
        console.log(`[AuthContext] Fetch caught abort for user ${userId}.`);
      } else {
        console.error(`[AuthContext] Failed to fetch profile for ${userId}:`, error.message);
      }
      return null;
    } finally {
      // Clean up the controller for this user ID once fetch is complete or aborted
      if (activeFetchControllers.get(userId) === controller) {
        activeFetchControllers.delete(userId);
        console.log(`[AuthContext] Cleaned up fetch controller for user: ${userId}`);
      }
    }
  };

  // Create a default profile for a new user
  const createDefaultProfile = async (userId: string, signal: AbortSignal) => { // Accept signal
    console.log(`[AuthContext] Starting createDefaultProfile for user: ${userId}`);
    try {
      // Adjust default profile to match the schema
      const defaultProfile = {
        id: userId,
        full_name: '',
        bio: '',
        location: '', // Use single location field
        website: '',
        avatar_url: '',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from('profiles')
        .insert([defaultProfile])
        .abortSignal(signal) // Pass signal
        .select()
        .single();

      if (signal.aborted) {
        console.log(`[AuthContext] Create default profile aborted for user ${userId} AFTER await.`);
        return null;
      }

      if (error) {
        if (error.message.includes('aborted')) {
          console.log(`[AuthContext] Create default profile explicitly aborted for user ${userId}.`);
          return null;
        }
        console.error(`[AuthContext] Error creating default profile for ${userId}:`, error.message);
        return null;
      }

      console.log("[AuthContext] Created default profile for user:", userId);
      return data as Profile;
    } catch (error: any) {
      if (error.name === 'AbortError' || error.message.includes('aborted')) {
        console.log(`[AuthContext] Create default profile caught abort for user ${userId}.`);
      } else {
        console.error(`[AuthContext] Failed to create default profile for ${userId}:`, error.message);
      }
      return null;
    }
  };

  // Refresh the user's profile data
  const refreshProfile = async () => {
    console.log('[AuthContext] refreshProfile called.')
    if (user) {
      console.log('[AuthContext] User exists, calling fetchProfile for:', user.id);
      const profileData = await fetchProfile(user.id);
      console.log('[AuthContext] Setting profile after refresh:', profileData);
      setProfile(profileData);
    } else {
      console.log('[AuthContext] refreshProfile called, but no user.')
    }
  };

  // Modify the useEffect in AuthContext for more efficient handling
  useEffect(() => {
    let mounted = true;
    console.log('[AuthContext] AuthProvider useEffect mounted.');

    // Store the AbortController for the initial profile fetch
    let initialFetchController: AbortController | null = null;

    async function checkSessionAndFetchProfile() {
      console.log('[AuthContext] Starting auth session check');
      // Keep loading true ONLY during session check
      setLoading(true); 
      let fetchedUser: User | null = null;

      try {
        const { data, error } = await supabase.auth.getSession();
        console.log('DEBUG: getSession response:', data, error);

        if (error) {
          console.error('DEBUG: Error during getSession:', error);
          if (mounted) setError(error);
        } else if (data && data.session) {
          console.log('DEBUG: Session found:', data.session);
          fetchedUser = data.session.user;
          if (mounted) {
            setUser(fetchedUser);
          }
        } else {
          console.log('DEBUG: No session data returned');
          if (mounted) {
            setUser(null);
            setProfile(null);
          }
        }
      } catch (e) {
        console.error('DEBUG: Unexpected error in checkSessionAndFetchProfile:', e);
        if (mounted) {
          setUser(null);
          setProfile(null);
        }
      } finally {
        // *** IMPORTANT: Set loading false AFTER session check is complete ***
        if (mounted) {
          console.log('DEBUG: Setting loading to false after session check');
          setLoading(false); 
        }
        
        // *** Fetch profile AFTER setting loading to false ***
        if (mounted && fetchedUser) {
          console.log(`[AuthContext] Triggering initial background profile fetch for user: ${fetchedUser.id}`);
          
          // Create and store the controller for this initial fetch
          initialFetchController = new AbortController();
          const initialSignal = initialFetchController.signal;
          
          fetchProfile(fetchedUser.id).then(profileData => { // fetchProfile now handles its own controller logic
            // The check `if (mounted)` is still good practice here
            if (mounted) {
               console.log('[AuthContext] Initial background profile fetch complete, setting profile:', profileData);
               setProfile(profileData);
            }
          }).catch(err => {
            if (err.name !== 'AbortError') { // Don't log aborts as errors here
              console.error('[AuthContext] Initial background profile fetch failed:', err);
            }
          }).finally(() => {
            initialFetchController = null; // Clear controller reference
          });
        }
      }
    }

    checkSessionAndFetchProfile();

    // Set up auth listener with optimized handling
    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        console.log('[AuthContext] Auth state changed:', { event, userId: session?.user?.id });
        
        if (!mounted) {
          console.log('[AuthContext] Auth state changed, but component unmounted. Ignoring.');
          return;
        }

        const currentUser = user; // Capture current user before potential update
        const newUser = session?.user ?? null;

        // Update user state immediately
        setUser(newUser);

        // If user logged out, clear profile
        if (!newUser) {
          setProfile(null);
          console.log('DEBUG: User logged out, clearing profile.');
          return; 
        }
        
        // If user changed or logged in, fetch profile in background
        if (newUser && (!currentUser || currentUser.id !== newUser.id)) {
           console.log(`[AuthContext] Triggering background profile fetch on auth change for user: ${newUser.id}`);
           fetchProfile(newUser.id).then(profileData => { // fetchProfile handles its own controller
             if (mounted) {
               console.log('[AuthContext] Background profile fetch complete on auth change, setting profile:', profileData);
               setProfile(profileData);
             }
           }).catch(err => {
             if (err.name !== 'AbortError') {
                console.error('[AuthContext] Background profile fetch failed on auth change:', err);
             }
           });
        } else if (newUser && currentUser && currentUser.id === newUser.id && !profile) {
          // If user is the same but profile somehow missing, try fetching again
          console.log(`[AuthContext] Re-triggering background profile fetch (user same, profile missing) for user: ${newUser.id}`);
          fetchProfile(newUser.id).then(profileData => { // fetchProfile handles its own controller
             if (mounted) {
               console.log('[AuthContext] Background profile fetch complete (refetch), setting profile:', profileData);
               setProfile(profileData);
             }
           }).catch(err => {
            if (err.name !== 'AbortError') {
               console.error('[AuthContext] Background profile fetch failed (refetch):', err);
            }
           });
        }
      }
    );

    // Cleanup function to run on unmount
    return () => {
      console.log('[AuthContext] AuthProvider useEffect cleanup.');
      mounted = false;
      authListener?.subscription?.unsubscribe();
      
      // Abort any pending initial fetch
      if (initialFetchController) {
        console.log('[AuthContext] Aborting initial fetch on unmount.');
        initialFetchController.abort();
      }
      
      // Abort all fetches managed by fetchProfile
      console.log(`[AuthContext] Aborting ${activeFetchControllers.size} potentially active fetches on unmount.`);
      activeFetchControllers.forEach(controller => controller.abort());
      activeFetchControllers.clear();
    };
  }, []); // Keep dependency array empty

  // Sign up with email and password
  const signUp = async (email: string, password: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase.auth.signUp({ email, password });
      
      if (error) {
        toast({ 
          title: "Sign up failed", 
          description: error.message,
          variant: "destructive" 
        });
        throw error;
      }
      
      toast({ 
        title: "Success!", 
        description: "Check your email to confirm your account.",
      });
      
      return { success: true, data };
    } catch (error: any) {
      console.error("Error signing up:", error.message);
      return { success: false, error: error.message };
    } finally {
      setLoading(false);
    }
  };

  // Sign in with email and password
  const signIn = async (email: string, password: string) => {
    try {
      setLoading(true);
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      
      if (error) {
        toast({ 
          title: "Sign in failed", 
          description: error.message,
          variant: "destructive" 
        });
        throw error;
      }
      
      toast({ 
        title: "Welcome back!", 
        description: `Signed in as ${email}`,
      });
      
      navigate('/dashboard');
      return { success: true, data };
    } catch (error: any) {
      console.error("Error signing in:", error.message);
      return { success: false, error: error.message };
    } finally {
      setLoading(false);
    }
  };

  // Sign out
  const signOut = async () => {
    try {
      setLoading(true);
      const { error } = await supabase.auth.signOut();
      
      if (error) {
        toast({ 
          title: "Sign out failed", 
          description: error.message,
          variant: "destructive" 
        });
        throw error;
      }
      
      // Clear user and profile state
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
      return { success: false, error: error.message };
    } finally {
      setLoading(false);
    }
  };

  const value = {
    user,
    profile,
    loading,
    signUp,
    signIn,
    signOut,
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
