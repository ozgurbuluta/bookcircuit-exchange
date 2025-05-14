import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, BookOpen, MapPin } from 'lucide-react';
import { useAuth } from '@/context/AuthContext';
import { getRecentlyAddedBooks, searchBooksByParams } from '@/lib/bookService';
import { Book, LocationData } from '@/lib/types';
import RequestableBookCard from '@/components/ui-custom/RequestableBookCard';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { 
  Card, 
  CardContent, 
  CardDescription, 
  CardHeader, 
  CardTitle 
} from '@/components/ui/card';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { supabase } from '@/lib/supabase';
import { PostalCodeAutocomplete } from '@/components/ui-custom/PostalCodeAutocomplete';
import { Slider } from '@/components/ui/slider';

// Form validation schema
const searchFormSchema = z.object({
  title: z.string().optional(),
  author: z.string().optional(),
  postalCode: z.string().optional(),
  radius: z.coerce.number().min(1).max(100).optional(),
});

type SearchFormValues = z.infer<typeof searchFormSchema>;

// --- START: Slider Mapping Logic ---
const allowedRadii = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, // 1km steps up to 10km
  15, 20, 25, 30, 35, 40, 45, 50, // 5km steps up to 50km
  60, 70, 80, 90, 100             // 10km steps up to 100km
];

const mapSliderIndexToRadius = (index: number): number => {
  // Clamp index to valid range
  const clampedIndex = Math.max(0, Math.min(index, allowedRadii.length - 1));
  return allowedRadii[clampedIndex];
};

const mapRadiusToSliderIndex = (radius: number): number => {
  let closestIndex = 0;
  let minDiff = Infinity;

  allowedRadii.forEach((allowedRadius, index) => {
    const diff = Math.abs(allowedRadius - radius);
    if (diff < minDiff) {
      minDiff = diff;
      closestIndex = index;
    }
  });
  return closestIndex;
};
// --- END: Slider Mapping Logic ---

const Home = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [recentBooks, setRecentBooks] = useState<Book[]>([]);
  const [searchResults, setSearchResults] = useState<Book[] | null>(null);
  const [isSearching, setIsSearching] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [owners, setOwners] = useState<Record<string, string>>({});
  const [locationData, setLocationData] = useState<LocationData | null>(null);

  // Initialize form
  const form = useForm<SearchFormValues>({
    resolver: zodResolver(searchFormSchema),
    defaultValues: {
      title: "",
      author: "",
      postalCode: "",
      radius: 10,
    },
  });

  // Fetch recent books when component mounts
  useEffect(() => {
    const fetchRecentBooks = async () => {
      try {
        const books = await getRecentlyAddedBooks(8);
        setRecentBooks(books);
        
        // Fetch owner names for the books
        await fetchOwnerNames(books);
      } catch (error) {
        console.error('Error fetching recent books:', error);
      } finally {
        setIsLoading(false);
      }
    };

    if (user) {
      fetchRecentBooks();
    } else {
      navigate('/signin');
    }
  }, [user, navigate]);

  // Fetch owner names for books
  const fetchOwnerNames = async (books: Book[]) => {
    try {
      // Get unique user IDs
      const userIds = [...new Set(books.map(book => book.user_id))];
      
      // Fetch profiles
      const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name')
        .in('id', userIds);
        
      if (error) {
        console.error('Error fetching profiles:', error);
        return;
      }
      
      // Create a map of user_id to full_name
      const ownerMap: Record<string, string> = {};
      data.forEach(profile => {
        ownerMap[profile.id] = profile.full_name || 'Anonymous';
      });
      
      setOwners(ownerMap);
    } catch (error) {
      console.error('Error fetching owner names:', error);
    }
  };

  // Handle search form submission
  const onSubmit = async (values: SearchFormValues) => {
    setIsSearching(true);
    try {
      // Prepare search parameters
      const searchParams = {
        title: values.title || undefined,
        author: values.author || undefined,
        postal_code: locationData?.postalCode || values.postalCode || undefined,
        radius: values.radius || undefined,
        latitude: locationData?.lat,
        longitude: locationData?.lng,
      };
      
      // At least one search parameter should be provided
      const hasSearchParam = Object.values(searchParams).some(val => val !== undefined);
      if (!hasSearchParam) {
        setSearchResults([]);
        return;
      }
      
      // Search books
      const results = await searchBooksByParams(searchParams);
      setSearchResults(results);
      
      // Fetch owner names for search results
      if (results.length > 0) {
        await fetchOwnerNames(results);
      }
      
    } catch (error) {
      console.error('Error searching books:', error);
    } finally {
      setIsSearching(false);
    }
  };

  // Handle location selection for search
  const handleLocationChange = (value: string, locData?: LocationData) => {
    form.setValue('postalCode', value);
    if (locData) {
      setLocationData(locData);
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      
      <main className="flex-grow container mx-auto px-4 pt-36 pb-8">
        <h1 className="text-3xl md:text-4xl font-bold font-serif mb-8">Welcome to Turtle Turning Pages</h1>
        
        {/* Search Form */}
        <Card className="mb-10">
          <CardHeader>
            <CardTitle>Find Books</CardTitle>
            <CardDescription>
              Search for books by title, author, or location
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <FormField
                    control={form.control}
                    name="title"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Title</FormLabel>
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
                    name="postalCode"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Postal Code</FormLabel>
                        <FormControl>
                          <PostalCodeAutocomplete
                            value={field.value || ''}
                            onChange={handleLocationChange}
                            placeholder="Enter postal code or address"
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  <FormField
                    control={form.control}
                    name="radius"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="flex justify-between">
                          <span>Radius (km)</span>
                          <span className="text-sm font-medium text-muted-foreground">
                            {field.value || form.formState.defaultValues?.radius} km
                          </span>
                        </FormLabel>
                        <FormControl>
                          <div className="flex items-center h-10 px-3 rounded-md border border-input bg-background">
                            <Slider
                              name={field.name}
                              value={[
                                mapRadiusToSliderIndex(
                                  field.value || form.formState.defaultValues?.radius || 10
                                )
                              ]}
                              min={0}
                              max={allowedRadii.length - 1}
                              step={1}
                              onValueChange={(value) => field.onChange(mapSliderIndexToRadius(value[0]))}
                              className="w-full"
                            />
                          </div>
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
                
                <Button type="submit" className="w-full" disabled={isSearching}>
                  {isSearching ? 'Searching...' : 'Search Books'}
                  <Search className="ml-2 h-4 w-4" />
                </Button>
              </form>
            </Form>
          </CardContent>
        </Card>
        
        {/* Search Results */}
        {searchResults !== null && (
          <div className="mb-10">
            <h2 className="text-2xl font-semibold mb-4">
              Search Results
              <span className="text-sm font-normal text-muted-foreground ml-2">
                ({searchResults.length} {searchResults.length === 1 ? 'book' : 'books'} found)
              </span>
            </h2>
            
            {/* Display location search indicator */}
            {searchResults.length > 0 && searchResults[0].distance_km !== undefined && (
              <div className="flex items-center mb-4 p-2 bg-blue-50 rounded-md border border-blue-200">
                <MapPin className="h-4 w-4 text-blue-500 mr-2" />
                <span className="text-sm text-blue-700">
                  Showing books within {form.getValues('radius') || 10}km of your location, sorted by distance
                </span>
              </div>
            )}
            
            {searchResults.length === 0 ? (
              <div className="text-center p-8 border rounded-lg">
                <BookOpen className="h-12 w-12 mx-auto mb-4 text-muted-foreground opacity-20" />
                <p className="text-muted-foreground">No books found matching your search criteria</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {searchResults.map(book => (
                  <RequestableBookCard
                    key={book.id}
                    book={book}
                    ownerName={owners[book.user_id] || 'Unknown'}
                    onRequest={() => {
                      // Refresh data after request
                      form.handleSubmit(onSubmit)();
                    }}
                    onCancel={() => {
                      // Refresh data after cancellation
                      form.handleSubmit(onSubmit)();
                    }}
                  />
                ))}
              </div>
            )}
          </div>
        )}
        
        {/* Recently Added Books */}
        <h2 className="text-2xl font-semibold mb-4">Recently Added Books</h2>
        
        {isLoading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {Array.from({ length: 8 }).map((_, index) => (
              <Card key={index} className="h-80 animate-pulse">
                <div className="h-full flex flex-col">
                  <div className="h-48 bg-muted rounded-t-lg"></div>
                  <div className="p-4 space-y-2">
                    <div className="h-4 bg-muted rounded w-3/4"></div>
                    <div className="h-3 bg-muted rounded w-1/2"></div>
                    <div className="h-3 bg-muted rounded w-2/3 mt-4"></div>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        ) : recentBooks.length === 0 ? (
          <div className="text-center p-8 border rounded-lg">
            <BookOpen className="h-12 w-12 mx-auto mb-4 text-muted-foreground opacity-20" />
            <p className="text-muted-foreground">No books available yet</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {recentBooks.map(book => (
              <RequestableBookCard
                key={book.id}
                book={book}
                ownerName={owners[book.user_id] || 'Unknown'}
                onRequest={() => {
                  // Refresh data after request
                  const fetchRecentBooks = async () => {
                    const books = await getRecentlyAddedBooks(8);
                    setRecentBooks(books);
                    await fetchOwnerNames(books);
                  };
                  fetchRecentBooks();
                }}
                onCancel={() => {
                  // Refresh data after cancellation
                  const fetchRecentBooks = async () => {
                    const books = await getRecentlyAddedBooks(8);
                    setRecentBooks(books);
                    await fetchOwnerNames(books);
                  };
                  fetchRecentBooks();
                }}
              />
            ))}
          </div>
        )}
      </main>
      
      <Footer />
    </div>
  );
};

export default Home; 