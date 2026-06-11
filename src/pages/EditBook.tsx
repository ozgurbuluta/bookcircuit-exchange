import { useState, useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Loader2, Save, ArrowLeft, Upload, X } from 'lucide-react';
import { toast } from 'sonner';

import { useAuth } from '@/context/AuthContext';
import { getBookById, updateBook } from '../lib/bookService';
import { uploadBookCover } from '../lib/storageService';
import { BookCondition, LocationData, Book, BOOK_CONDITIONS } from '../lib/types';

import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Textarea } from '../components/ui/textarea';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '../components/ui/form';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '../components/ui/card';
import { Separator } from '../components/ui/separator';
import { PostalCodeAutocomplete } from '../components/ui-custom/PostalCodeAutocomplete';

// Form validation schema
const bookFormSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  author: z.string().optional(),
  location_text: z.string().min(1, 'Location is required'),
  condition: z.enum(BOOK_CONDITIONS as unknown as [BookCondition, ...BookCondition[]]),
  cover_img_url: z.string().optional(),
  isbn: z.string().optional(),
  description: z.string().optional(),
  custom_cover_image: z.any().optional(),
});

type BookFormValues = z.infer<typeof bookFormSchema>;

export default function EditBook() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>(); // Get book ID from URL params
  const { user, loading: authLoading } = useAuth();
  const [book, setBook] = useState<Book | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadingBook, setLoadingBook] = useState(true);
  const [locationData, setLocationData] = useState<LocationData | null>(null);
  const [customImagePreview, setCustomImagePreview] = useState<string | null>(null);
  const [customImageBlob, setCustomImageBlob] = useState<Blob | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initialize form with empty values (will be populated once book is loaded)
  const form = useForm<BookFormValues>({
    resolver: zodResolver(bookFormSchema),
    defaultValues: {
      title: '',
      author: '',
      location_text: '',
      condition: 'Good',
      cover_img_url: '',
      isbn: '',
      description: '',
    },
  });

  // Redirect unauthenticated users once auth state has resolved
  useEffect(() => {
    if (!authLoading && !user) {
      navigate('/signin');
    }
  }, [user, authLoading, navigate]);
  
  // Load book data
  useEffect(() => {
    const loadBook = async () => {
      if (!id) {
        toast.error('No book ID provided');
        navigate('/dashboard');
        return;
      }
      
      setLoadingBook(true);
      try {
        const loadedBook = await getBookById(id);
        if (!loadedBook) {
          toast.error('Book not found');
          navigate('/dashboard');
          return;
        }

        // Ownership guard: only the owner may edit a listing. Firestore rules
        // enforce this server-side too; this provides immediate UX feedback.
        if (user && loadedBook.user_id && loadedBook.user_id !== user.uid) {
          toast.error('You can only edit your own books');
          navigate('/dashboard');
          return;
        }

        setBook(loadedBook);
        
        // Populate form with book data
        form.reset({
          title: loadedBook.title,
          author: loadedBook.author || '',
          location_text: loadedBook.location_text || '',
          condition: loadedBook.condition,
          cover_img_url: loadedBook.cover_img_url || '',
          isbn: loadedBook.isbn || '',
          description: loadedBook.description || '',
        });
        
        // Set location data if postal_code exists
        if (loadedBook.postal_code) {
          setLocationData({
            postalCode: loadedBook.postal_code,
            formattedAddress: loadedBook.location_text || '',
            lat: loadedBook.location_lat,
            lng: loadedBook.location_lng
          });
        }
        
      } catch (error) {
        console.error('Error loading book:', error);
        toast.error('Failed to load book');
        navigate('/dashboard');
      } finally {
        setLoadingBook(false);
      }
    };
    
    if (user) {
      loadBook();
    }
  }, [id, user, navigate, form]);

  // Handle image upload
  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Check file size (limit to 2MB to stay safely within database limits)
      if (file.size > 2 * 1024 * 1024) {
        toast.error('Image size should be less than 2MB');
        return;
      }
      
      // Check file type
      if (!file.type.startsWith('image/')) {
        toast.error('Only image files are allowed');
        return;
      }
      
      // Create a smaller version of the image to limit size
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          // Resize image if it's too large
          const maxWidth = 600;
          const maxHeight = 800;
          let width = img.width;
          let height = img.height;
          
          if (width > maxWidth || height > maxHeight) {
            if (width / height > maxWidth / maxHeight) {
              // Width is the limiting factor
              height = height * maxWidth / width;
              width = maxWidth;
            } else {
              // Height is the limiting factor
              width = width * maxHeight / height;
              height = maxHeight;
            }
          }
          
          // Create a canvas to resize the image
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext('2d');
          ctx?.drawImage(img, 0, 0, width, height);
          
          // Convert to a data URL for local preview only
          const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
          setCustomImagePreview(dataUrl);

          // Capture a Blob to upload to Storage on submit (avoids storing
          // base64 in the Firestore document)
          canvas.toBlob(
            (blob) => {
              if (blob) setCustomImageBlob(blob);
            },
            'image/jpeg',
            0.8
          );
        };
        img.src = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  };

  // Handle removing custom image
  const handleRemoveCustomImage = () => {
    setCustomImagePreview(null);
    setCustomImageBlob(null);
    // Restore original book cover if available
    if (book && book.cover_img_url) {
      form.setValue('cover_img_url', book.cover_img_url);
    } else {
      form.setValue('cover_img_url', '');
    }
    // Reset file input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  // Handle location selection
  const handleLocationChange = (value: string, locData?: LocationData) => {
    form.setValue('location_text', value);
    if (locData) {
      setLocationData(locData);
    }
  };

  // Handle form submission
  const onSubmit = async (data: BookFormValues) => {
    if (!user) {
      toast.error('You must be logged in to update a book');
      return;
    }
    
    if (!id) {
      toast.error('No book ID provided');
      return;
    }

    setLoading(true);
    try {
      // If the user picked a new custom cover, upload it to Storage and store
      // only the resulting download URL (never base64 in the Firestore document).
      let coverImgUrl = data.cover_img_url;
      if (customImageBlob) {
        const uploadResult = await uploadBookCover(customImageBlob);
        if (!uploadResult.success || !uploadResult.url) {
          throw new Error(uploadResult.error || 'Failed to upload cover image');
        }
        coverImgUrl = uploadResult.url;
      } else if (coverImgUrl && coverImgUrl.startsWith('data:')) {
        // Defensive: never persist a data URL into Firestore.
        coverImgUrl = book?.cover_img_url && !book.cover_img_url.startsWith('data:')
          ? book.cover_img_url
          : '';
      }

      // Prepare book data for update
      const bookData = {
        title: data.title,
        author: data.author,
        location_text: data.location_text,
        condition: data.condition as BookCondition,
        cover_img_url: coverImgUrl,
        isbn: data.isbn,
        description: data.description,
        // Add additional location data if available
        ...(locationData && {
          postal_code: locationData.postalCode,
          lat: locationData.lat,
          lng: locationData.lng
        })
      };

      const result = await updateBook(id, bookData);
      
      if (result.success) {
        toast.success('Book updated successfully!');
        navigate('/dashboard');
      } else {
        toast.error(result.error || 'Failed to update book');
      }
    } catch (error) {
      console.error('Error updating book:', error);
      toast.error('An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  if (loadingBook) {
    return (
      <div className="container max-w-4xl py-10 flex flex-col items-center justify-center min-h-[60vh]">
        <Loader2 className="h-8 w-8 animate-spin mb-4" />
        <p className="text-lg text-muted-foreground">Loading book details...</p>
      </div>
    );
  }

  return (
    <div className="container max-w-4xl py-10">
      <div className="flex items-center gap-4 mb-6">
        <Button
          variant="ghost"
          onClick={() => navigate('/dashboard')}
          className="p-0 h-9 w-9"
        >
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-3xl font-bold">Edit Book</h1>
      </div>
      
      {/* Book Form */}
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Book Details</CardTitle>
              <CardDescription>
                Edit your book's information
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-6">
                  <FormField
                    control={form.control}
                    name="title"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Title *</FormLabel>
                        <FormControl>
                          <Input placeholder="Book title" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="author"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Author</FormLabel>
                        <FormControl>
                          <Input placeholder="Author name" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="location_text"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Location *</FormLabel>
                        <FormControl>
                          <PostalCodeAutocomplete
                            value={field.value}
                            onChange={handleLocationChange}
                            placeholder="Enter a postal code or address..."
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="condition"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Condition *</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue placeholder="Select condition" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {BOOK_CONDITIONS.map((condition) => (
                              <SelectItem key={condition} value={condition}>
                                {condition}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="isbn"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>ISBN</FormLabel>
                        <FormControl>
                          <Input placeholder="ISBN (optional)" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
                
                <div className="space-y-6">
                  <FormField
                    control={form.control}
                    name="cover_img_url"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Cover Image</FormLabel>
                        <div className="mb-2">
                          {field.value ? (
                            <div className="relative inline-block">
                              <img 
                                src={field.value} 
                                alt="Book cover preview" 
                                className="max-w-[120px] max-h-[180px] object-contain rounded border"
                                onError={(e) => {
                                  (e.target as HTMLImageElement).style.display = 'none';
                                }}
                              />
                            </div>
                          ) : (
                            <div className="w-[120px] h-[180px] bg-muted rounded border flex items-center justify-center">
                              <span className="text-sm text-muted-foreground">No cover image</span>
                            </div>
                          )}
                        </div>
                        <div className="flex flex-col gap-2">
                          <Button 
                            type="button" 
                            variant="outline" 
                            size="sm" 
                            onClick={() => fileInputRef.current?.click()}
                            className="w-fit"
                          >
                            <Upload className="h-4 w-4 mr-2" />
                            Upload Cover Image
                          </Button>
                          {customImagePreview && (
                            <Button 
                              type="button" 
                              variant="destructive" 
                              size="sm" 
                              onClick={handleRemoveCustomImage}
                              className="w-fit"
                            >
                              <X className="h-4 w-4 mr-2" />
                              Remove Custom Image
                            </Button>
                          )}
                        </div>
                        <input 
                          type="file" 
                          accept="image/*" 
                          ref={fileInputRef}
                          onChange={handleImageUpload}
                          className="hidden"
                        />
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="description"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Description</FormLabel>
                        <FormControl>
                          <Textarea 
                            placeholder="Book description (optional)" 
                            className="min-h-[180px]"
                            {...field} 
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
              </div>
            </CardContent>
            <CardFooter className="flex justify-end gap-4 pt-4">
              <Button 
                type="button" 
                variant="outline" 
                onClick={() => navigate('/dashboard')}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={loading}>
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Saving Changes...
                  </>
                ) : (
                  <>
                    <Save className="mr-2 h-4 w-4" />
                    Save Changes
                  </>
                )}
              </Button>
            </CardFooter>
          </Card>
        </form>
      </Form>
    </div>
  );
} 