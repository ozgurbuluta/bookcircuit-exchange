import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Loader2, Search, BookPlus, Upload, X } from 'lucide-react';
import { toast } from 'sonner';

import Navbar from '../components/ui-custom/Navbar';
import Footer from '../components/ui-custom/Footer';
import { useAuth } from '@/context/AuthContext';
import { searchBooks, formatBookData, addBook } from '../lib/bookService';
import { BookCondition, OpenLibraryBook, LocationData } from '../lib/types';

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
  condition: z.enum(['New', 'Like New', 'Good', 'Fair', 'Poor']),
  cover_img_url: z.string().optional(),
  isbn: z.string().optional(),
  description: z.string().optional(),
  custom_cover_image: z.any().optional(),
});

type BookFormValues = z.infer<typeof bookFormSchema>;

export default function AddBook() {
  const navigate = useNavigate();
  const { user, loading: authLoading } = useAuth();
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<OpenLibraryBook[]>([]);
  const [searching, setSearching] = useState(false);
  const [selectedBook, setSelectedBook] = useState<OpenLibraryBook | null>(null);
  const [locationData, setLocationData] = useState<LocationData | null>(null);
  const [customImagePreview, setCustomImagePreview] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initialize form with default values
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

  // Check if user is authenticated
  useEffect(() => {
    if (!authLoading && !user) {
      navigate('/signin');
    }
  }, [user, authLoading, navigate]);

  // Handle book search
  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    
    setSearching(true);
    try {
      const results = await searchBooks(searchQuery);
      setSearchResults(results);
    } catch (error) {
      console.error('Error searching books:', error);
      toast.error('Failed to search books. Please try again.');
    } finally {
      setSearching(false);
    }
  };

  // Handle book selection from search results
  const handleSelectBook = (book: OpenLibraryBook) => {
    setSelectedBook(book);
    const formattedBook = formatBookData(book);
    
    // Debug log to verify data extraction
    console.log('Selected book data:', {
      original: book,
      formatted: formattedBook
    });
    
    // Update form values with selected book data
    form.setValue('title', formattedBook.title || '');
    if (formattedBook.author) form.setValue('author', formattedBook.author);
    if (formattedBook.isbn) form.setValue('isbn', formattedBook.isbn);
    if (formattedBook.description) form.setValue('description', formattedBook.description);
    if (formattedBook.cover_img_url) form.setValue('cover_img_url', formattedBook.cover_img_url);
    
    // Reset custom image if book is changed
    setCustomImagePreview(null);
    
    // Clear search results
    setSearchResults([]);
    setSearchQuery('');
  };

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
          
          // Convert to a data URL with reduced quality
          const dataUrl = canvas.toDataURL('image/jpeg', 0.8);
          
          setCustomImagePreview(dataUrl);
          form.setValue('cover_img_url', dataUrl);
        };
        img.src = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  };

  // Handle removing custom image
  const handleRemoveCustomImage = () => {
    setCustomImagePreview(null);
    // Restore API cover image if available
    if (selectedBook) {
      const formattedBook = formatBookData(selectedBook);
      if (formattedBook.cover_img_url) {
        form.setValue('cover_img_url', formattedBook.cover_img_url);
      } else {
        form.setValue('cover_img_url', '');
      }
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
      toast.error('You must be logged in to add a book');
      return;
    }

    setLoading(true);
    try {
      // Check if the cover_img_url is a data URL that might be too large
      let coverImgUrl = data.cover_img_url;
      if (coverImgUrl && coverImgUrl.startsWith('data:') && coverImgUrl.length > 500000) {
        console.warn('Image is very large, might cause issues with database storage');
        // Optionally add your fallback logic here if needed
      }
      
      // Ensure all required fields are present
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
      
      const result = await addBook(user.uid, bookData);
      
      if (result.success) {
        toast.success('Book added successfully!');
        navigate('/dashboard');
      } else {
        toast.error(result.error || 'Failed to add book');
      }
    } catch (error) {
      console.error('Error adding book:', error);
      toast.error('An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <Navbar />
      <div className="container mx-auto py-8 px-4 sm:px-6 lg:px-8 flex-grow">
        <h1 className="text-3xl font-bold text-center mb-8">Add a Book to Your Collection</h1>
        
        {/* Book Search Section */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Search for a Book</CardTitle>
            <CardDescription>
              Find a book by title, author, or ISBN to auto-fill the form
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex gap-2">
              <Input
                placeholder="Search by title, author, or ISBN..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                className="flex-1"
              />
              <Button onClick={handleSearch} disabled={searching}>
                {searching ? <Loader2 className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />}
                Search
              </Button>
            </div>
            
            {/* Search Results */}
            {searchResults.length > 0 && (
              <div className="mt-4 border rounded-md divide-y">
                {searchResults.map((book, index) => (
                  <div 
                    key={index} 
                    className="p-3 hover:bg-muted cursor-pointer flex items-start gap-3"
                    onClick={() => handleSelectBook(book)}
                  >
                    {book.covers?.[0] && (
                      <img 
                        src={`https://covers.openlibrary.org/b/id/${book.covers[0]}-M.jpg`} 
                        alt={book.title}
                        className="w-12 h-16 object-cover rounded"
                      />
                    )}
                    {!book.covers?.[0] && book.cover_i && (
                      <img 
                        src={`https://covers.openlibrary.org/b/id/${book.cover_i}-M.jpg`} 
                        alt={book.title}
                        className="w-12 h-16 object-cover rounded"
                      />
                    )}
                    <div>
                      <h3 className="font-medium">{book.title}</h3>
                      {book.authors?.[0] && <p className="text-sm text-muted-foreground">{book.authors[0].name}</p>}
                      {book.publish_date && <p className="text-xs text-muted-foreground">Published: {book.publish_date}</p>}
                    </div>
                  </div>
                ))}
              </div>
            )}
            
            {/* Selected Book Preview */}
            {selectedBook && (
              <div className="mt-4 p-4 border rounded-md bg-muted/30">
                <h3 className="text-lg font-medium mb-2">Selected Book</h3>
                <div className="flex gap-4">
                  <div className="relative">
                    {form.getValues('cover_img_url') && (
                      <img 
                        src={form.getValues('cover_img_url')} 
                        alt={form.getValues('title')}
                        className="w-24 h-32 object-cover rounded" 
                      />
                    )}
                    <div className="mt-2 flex flex-col gap-2">
                      <Button 
                        type="button" 
                        variant="outline" 
                        size="sm" 
                        className="w-full text-xs"
                        onClick={() => fileInputRef.current?.click()}
                      >
                        <Upload className="h-3 w-3 mr-1" />
                        Custom Cover
                      </Button>
                      {customImagePreview && (
                        <Button 
                          type="button" 
                          variant="destructive" 
                          size="sm" 
                          className="w-full text-xs"
                          onClick={handleRemoveCustomImage}
                        >
                          <X className="h-3 w-3 mr-1" />
                          Remove
                        </Button>
                      )}
                      <input 
                        type="file" 
                        accept="image/*" 
                        ref={fileInputRef}
                        onChange={handleImageUpload}
                        className="hidden"
                      />
                    </div>
                  </div>
                  <div className="flex-1">
                    <p className="font-medium text-lg">{form.getValues('title')}</p>
                    {form.getValues('author') ? (
                      <p className="text-sm font-medium text-muted-foreground">
                        <span className="font-semibold">Author:</span> {form.getValues('author')}
                      </p>
                    ) : null}
                    {form.getValues('isbn') ? (
                      <p className="text-sm font-medium text-muted-foreground">
                        <span className="font-semibold">ISBN:</span> {form.getValues('isbn')}
                      </p>
                    ) : null}
                    {form.getValues('description') && (
                      <p className="text-sm text-muted-foreground mt-2 line-clamp-2">
                        {form.getValues('description')}
                      </p>
                    )}
                  </div>
                </div>
                <p className="text-sm text-muted-foreground mt-2">
                  All fields have been automatically filled. You can edit them or upload a custom cover image.
                </p>
              </div>
            )}
          </CardContent>
        </Card>
        
        {/* Book Form */}
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
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
                          <SelectItem value="New">New</SelectItem>
                          <SelectItem value="Like New">Like New</SelectItem>
                          <SelectItem value="Good">Good</SelectItem>
                          <SelectItem value="Fair">Fair</SelectItem>
                          <SelectItem value="Poor">Poor</SelectItem>
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
                      <FormLabel>Cover Image URL</FormLabel>
                      <FormControl>
                        <Input placeholder="URL to book cover (optional)" {...field} />
                      </FormControl>
                      <FormMessage />
                      {field.value && (
                        <div className="mt-2">
                          <img 
                            src={field.value} 
                            alt="Book cover preview" 
                            className="max-w-[120px] max-h-[180px] object-cover rounded border"
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                            }}
                          />
                        </div>
                      )}
                      <div className="mt-2">
                        <Button 
                          type="button" 
                          variant="outline" 
                          size="sm" 
                          onClick={() => fileInputRef.current?.click()}
                        >
                          <Upload className="h-4 w-4 mr-2" />
                          Upload Cover Image
                        </Button>
                      </div>
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
                          className="min-h-[150px]"
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </div>
            
            <div className="flex justify-end gap-4 pt-4">
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
                    Adding Book...
                  </>
                ) : (
                  <>
                    <BookPlus className="mr-2 h-4 w-4" />
                    Add Book
                  </>
                )}
              </Button>
            </div>
          </form>
        </Form>
      </div>
      <Footer />
    </div>
  );
} 