import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Save, X, Upload, Camera, Loader2 } from 'lucide-react';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import Button from '@/components/ui-custom/Button';
import { useAuth } from '@/context/AuthContext';
import { getProfileById, updateProfile } from '@/lib/profileService';
import { uploadAvatar } from '@/lib/storageService';
import { toast } from "@/components/ui/use-toast";

interface UserProfile {
  id: string;
  full_name: string;
  bio: string;
  location: string;
  favorite_genre: string;
  website: string;
  avatar_url: string | null;
}

const Profile = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [profile, setProfile] = useState<UserProfile>({
    id: user?.id || '',
    full_name: '',
    bio: '',
    location: '',
    favorite_genre: '',
    website: '',
    avatar_url: null
  });

  useEffect(() => {
    if (user) {
      fetchProfile();
    }
  }, [user]);

  const fetchProfile = async () => {
    try {
      setLoading(true);

      const data = await getProfileById(user?.id || '');

      if (data) {
        setProfile({
          id: user?.id || '',
          full_name: data.full_name || '',
          bio: data.bio || '',
          location: data.location_city || '',
          favorite_genre: '',
          website: data.website || '',
          avatar_url: data.avatar_url || null
        });
      }
    } catch (error: any) {
      console.error('Error:', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setProfile(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) return;

    try {
      setUpdating(true);

      const result = await updateProfile(user.id, {
        full_name: profile.full_name,
        bio: profile.bio,
        location_city: profile.location,
        website: profile.website,
        avatar_url: profile.avatar_url || undefined,
      });

      if (!result.success) {
        throw new Error(result.error);
      }

      toast({
        title: "Profile updated",
        description: "Your profile has been successfully updated",
      });
    } catch (error: any) {
      console.error('Error updating profile:', error.message);
      toast({
        title: "Update failed",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setUpdating(false);
    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0) {
      return;
    }

    const file = e.target.files[0];

    try {
      setAvatarUploading(true);

      const result = await uploadAvatar(file);

      if (!result.success || !result.url) {
        throw new Error(result.error || 'Upload failed');
      }

      // Update profile with avatar URL
      const updateResult = await updateProfile(user?.id || '', {
        avatar_url: result.url
      });

      if (!updateResult.success) {
        throw new Error(updateResult.error);
      }

      // Update local state
      setProfile(prev => ({
        ...prev,
        avatar_url: result.url!
      }));

      toast({
        title: "Avatar uploaded",
        description: "Your profile image has been updated",
      });
    } catch (error: any) {
      console.error('Error uploading avatar:', error.message);
      toast({
        title: "Upload failed",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setAvatarUploading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-grow pt-28 pb-20 flex items-center justify-center">
          <div className="flex items-center">
            <Loader2 className="h-8 w-8 animate-spin text-book-accent mr-2" />
            <span className="text-book-dark">Loading profile...</span>
          </div>
        </main>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-grow pt-28 pb-20">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-4xl mx-auto">
            <div className="glass-card rounded-xl p-8 shadow-lg mb-8">
              <div className="flex items-center mb-8">
                <User className="h-6 w-6 text-book-accent mr-2" />
                <h1 className="text-2xl md:text-3xl font-bold font-serif">Your Profile</h1>
              </div>

              <form onSubmit={handleSubmit}>
                <div className="mb-8 flex flex-col items-center">
                  <div className="relative mb-4">
                    {avatarUploading ? (
                      <div className="w-32 h-32 rounded-full bg-book-light/50 flex items-center justify-center">
                        <Loader2 className="h-8 w-8 animate-spin text-book-accent" />
                      </div>
                    ) : (
                      profile.avatar_url ? (
                        <img
                          src={profile.avatar_url}
                          alt="Profile"
                          className="w-32 h-32 rounded-full object-cover border-2 border-book-accent"
                        />
                      ) : (
                        <div className="w-32 h-32 rounded-full bg-book-light/50 flex items-center justify-center">
                          <User className="h-16 w-16 text-book-accent/40" />
                        </div>
                      )
                    )}
                    <label
                      htmlFor="avatar-upload"
                      className="absolute bottom-0 right-0 bg-book-accent text-white p-2 rounded-full cursor-pointer hover:bg-book-accent/80 transition-colors"
                    >
                      <Camera className="h-5 w-5" />
                    </label>
                    <input
                      id="avatar-upload"
                      type="file"
                      className="hidden"
                      accept="image/*"
                      onChange={handleAvatarUpload}
                      disabled={avatarUploading}
                    />
                  </div>
                  <p className="text-sm text-book-dark/60">Click the camera icon to upload a profile image</p>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label className="block text-book-dark font-medium mb-2">
                      Full Name
                    </label>
                    <input
                      type="text"
                      name="full_name"
                      value={profile.full_name}
                      onChange={handleChange}
                      className="w-full p-3 rounded-md bg-white/80 border border-book-light focus:outline-none focus:ring-2 focus:ring-book-accent/50 transition-all"
                      placeholder="Your full name"
                    />
                  </div>

                  <div>
                    <label className="block text-book-dark font-medium mb-2">
                      Location
                    </label>
                    <input
                      type="text"
                      name="location"
                      value={profile.location}
                      onChange={handleChange}
                      className="w-full p-3 rounded-md bg-white/80 border border-book-light focus:outline-none focus:ring-2 focus:ring-book-accent/50 transition-all"
                      placeholder="City, Country"
                    />
                  </div>

                  <div>
                    <label className="block text-book-dark font-medium mb-2">
                      Favorite Book Genre
                    </label>
                    <input
                      type="text"
                      name="favorite_genre"
                      value={profile.favorite_genre}
                      onChange={handleChange}
                      className="w-full p-3 rounded-md bg-white/80 border border-book-light focus:outline-none focus:ring-2 focus:ring-book-accent/50 transition-all"
                      placeholder="e.g. Science Fiction, Fantasy, etc."
                    />
                  </div>

                  <div>
                    <label className="block text-book-dark font-medium mb-2">
                      Website or Social Profile
                    </label>
                    <input
                      type="text"
                      name="website"
                      value={profile.website}
                      onChange={handleChange}
                      className="w-full p-3 rounded-md bg-white/80 border border-book-light focus:outline-none focus:ring-2 focus:ring-book-accent/50 transition-all"
                      placeholder="https://example.com"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="block text-book-dark font-medium mb-2">
                      Bio
                    </label>
                    <textarea
                      name="bio"
                      value={profile.bio}
                      onChange={handleChange}
                      rows={4}
                      className="w-full p-3 rounded-md bg-white/80 border border-book-light focus:outline-none focus:ring-2 focus:ring-book-accent/50 transition-all resize-none"
                      placeholder="Tell us a bit about yourself and your reading interests..."
                    />
                  </div>
                </div>

                <div className="mt-8 flex justify-end space-x-4">
                  <Button
                    type="button"
                    variant="outline"
                    as="a"
                    href="/dashboard"
                  >
                    <X className="mr-2 h-4 w-4" />
                    Cancel
                  </Button>
                  <Button
                    type="submit"
                    variant="primary"
                    disabled={updating}
                  >
                    {updating ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Saving...
                      </>
                    ) : (
                      <>
                        <Save className="mr-2 h-4 w-4" />
                        Save Profile
                      </>
                    )}
                  </Button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Profile;
