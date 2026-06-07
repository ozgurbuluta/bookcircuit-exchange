import { storage, auth } from './firebase';
import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';

// Upload avatar image
export const uploadAvatar = async (
  file: File
): Promise<{ success: boolean; url?: string; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    const fileExt = file.name.split('.').pop();
    const fileName = `avatar-${Date.now()}.${fileExt}`;
    const filePath = `avatars/${user.uid}/${fileName}`;

    const storageRef = ref(storage, filePath);
    await uploadBytes(storageRef, file);

    const url = await getDownloadURL(storageRef);

    return { success: true, url };
  } catch (error) {
    console.error('Error uploading avatar:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Upload failed',
    };
  }
};

// Upload book cover image
export const uploadBookCover = async (
  file: File,
  bookId: string
): Promise<{ success: boolean; url?: string; error?: string }> => {
  try {
    const user = auth.currentUser;
    if (!user) {
      return { success: false, error: 'Not authenticated' };
    }

    const fileExt = file.name.split('.').pop();
    const fileName = `cover-${Date.now()}.${fileExt}`;
    const filePath = `books/${bookId}/${fileName}`;

    const storageRef = ref(storage, filePath);
    await uploadBytes(storageRef, file);

    const url = await getDownloadURL(storageRef);

    return { success: true, url };
  } catch (error) {
    console.error('Error uploading book cover:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Upload failed',
    };
  }
};

// Delete file from storage
export const deleteFile = async (fileUrl: string): Promise<boolean> => {
  try {
    // Extract the path from the URL
    const storageRef = ref(storage, fileUrl);
    await deleteObject(storageRef);
    return true;
  } catch (error) {
    console.error('Error deleting file:', error);
    return false;
  }
};
