import { useEffect, useRef, useState } from 'react';
import { Input } from '@/components/ui/input';
import { MapPin, Loader2, AlertTriangle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { LocationData } from '@/lib/types';

// Initialize the Google Maps API script
const loadGoogleMapsScript = (apiKey: string, callback: (success: boolean, error?: string) => void) => {
  // Return early if API key is missing
  if (!apiKey) {
    console.error('Google Maps API key is not defined in environment variables');
    callback(false, 'API key is missing');
    return;
  }

  // Only load the script if it hasn't been loaded yet
  if (!window.google || !window.google.maps) {
    // Create a global callback function
    const callbackName = `googleMapsCallback_${Date.now()}`;
    (window as any)[callbackName] = () => {
      delete (window as any)[callbackName]; // Clean up
      callback(true);
    };
    
    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=places&callback=${callbackName}`;
    script.async = true;
    script.defer = true;
    
    script.onerror = () => {
      console.error('Failed to load Google Maps script');
      delete (window as any)[callbackName]; // Clean up
      callback(false, 'Failed to load Google Maps API');
    };
    
    // Set a timeout in case the callback is never triggered
    setTimeout(() => {
      if ((window as any)[callbackName]) {
        console.error('Google Maps callback timed out');
        delete (window as any)[callbackName];
        callback(false, 'Google Maps loading timed out');
      }
    }, 10000); // 10 second timeout
    
    document.head.appendChild(script);
  } else {
    callback(true);
  }
};

// New function to use the Places Autocomplete API
async function fetchAutocompleteSuggestions(
  input: string, 
  apiKey: string,
  latitude: number, 
  longitude: number
): Promise<LocationData[]> {
  try {
    // Using the new Places API :autocomplete endpoint
    const response = await fetch('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': '*'
      },
      body: JSON.stringify({
        input,
        locationBias: {
          circle: {
            center: {
              latitude,
              longitude
            },
            radius: 5000.0
          }
        }
      })
    });

    if (!response.ok) {
      throw new Error(`Places API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    
    // Process suggestions
    const locationResults: LocationData[] = [];
    
    if (data.suggestions && data.suggestions.length > 0) {
      // Process each place prediction
      for (const suggestion of data.suggestions) {
        if (suggestion.placePrediction) {
          const place = suggestion.placePrediction;
          
          // We need to make another API call to get geocoded information
          const geocoder = new google.maps.Geocoder();
          
          try {
            const geocodeResult = await new Promise<google.maps.GeocoderResult[]>((resolve, reject) => {
              geocoder.geocode(
                { placeId: place.placeId },
                (results, status) => {
                  if (status === 'OK' && results && results.length > 0) {
                    resolve(results);
                  } else {
                    reject(status);
                  }
                }
              );
            });
            
            if (geocodeResult && geocodeResult[0]) {
              const result = geocodeResult[0];
              const postalCode = result.address_components.find(
                component => component.types.includes('postal_code')
              )?.long_name || '';
              
              // Ensure we always store lat/lng properly for radius search
              const lat = result.geometry.location.lat();
              const lng = result.geometry.location.lng();
              
              locationResults.push({
                postalCode,
                formattedAddress: place.text.text || result.formatted_address,
                lat,
                lng,
              });
            }
          } catch (geocodeError) {
            console.error('Error geocoding place:', geocodeError);
          }
        }
      }
    }
    
    return locationResults;
  } catch (error) {
    console.error('Error fetching autocomplete suggestions:', error);
    throw error;
  }
}

interface PostalCodeAutocompleteProps {
  value: string;
  onChange: (value: string, locationData?: LocationData) => void;
  placeholder?: string;
}

export function PostalCodeAutocomplete({
  value,
  onChange,
  placeholder = 'Enter a postal code or address...'
}: PostalCodeAutocompleteProps) {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState(value || '');
  const [suggestions, setSuggestions] = useState<LocationData[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [apiStatus, setApiStatus] = useState<{
    loaded: boolean;
    loading: boolean;
    error: string | null;
  }>({
    loaded: false,
    loading: true,
    error: null
  });

  const geocoder = useRef<google.maps.Geocoder | null>(null);
  const debounceTimer = useRef<NodeJS.Timeout | null>(null);
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

  // Load Google Maps API
  useEffect(() => {
    if (!apiKey) {
      setApiStatus({
        loaded: false,
        loading: false,
        error: 'API key is missing from environment'
      });
      return;
    }
    
    loadGoogleMapsScript(apiKey, (success, error) => {
      if (success && window.google && window.google.maps) {
        try {
          geocoder.current = new window.google.maps.Geocoder();
          
          setApiStatus({
            loaded: true,
            loading: false,
            error: null
          });
          
        } catch (err) {
          console.error('Failed to initialize Google Maps services:', err);
          setApiStatus({
            loaded: false,
            loading: false,
            error: 'Failed to initialize location services'
          });
        }
      } else {
        setApiStatus({
          loaded: false,
          loading: false,
          error: error || 'Unknown error loading Google Maps API'
        });
      }
    });
    
    // Cleanup function
    return () => {
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current);
      }
    };
  }, [apiKey]);

  // Update input when value changes from props
  useEffect(() => {
    if (value && value !== input) {
      setInput(value);
    }
  }, [value]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newInput = e.target.value;
    setInput(newInput);
    
    // Clear any existing timer
    if (debounceTimer.current) {
      clearTimeout(debounceTimer.current);
    }
    
    // Set a new timer to delay the API call (debounce)
    debounceTimer.current = setTimeout(() => {
      if (newInput.trim()) {
        fetchSuggestions(newInput);
      } else {
        setSuggestions([]);
        setOpen(false);
      }
    }, 300); // 300ms debounce
  };

  const fetchSuggestions = async (query: string) => {
    if (!query || query.length < 2 || !apiStatus.loaded || !apiKey) {
      setSuggestions([]);
      return;
    }

    setIsLoading(true);
    setOpen(true);
    
    try {
      // Try to get user's current location for better suggestions
      let latitude = 37.7749; // Default (San Francisco)
      let longitude = -122.4194;
      
      try {
        if (navigator.geolocation) {
          const position = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, {
              timeout: 5000,
              maximumAge: 60000,
            });
          });
          
          latitude = position.coords.latitude;
          longitude = position.coords.longitude;
        }
      } catch (error) {
        console.warn('Could not get user location, using default:', error);
      }
      
      const results = await fetchAutocompleteSuggestions(
        query,
        apiKey,
        latitude,
        longitude
      );
      
      setSuggestions(results);
    } catch (error) {
      console.error('Error fetching suggestions:', error);
      setSuggestions([]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSelect = (location: LocationData) => {
    setInput(location.formattedAddress);
    onChange(location.formattedAddress, location);
    setSuggestions([]);
    setOpen(false);
  };

  const retryLoading = () => {
    setApiStatus({
      loaded: false,
      loading: true,
      error: null
    });
    
    // Reload the page to reload the API
    window.location.reload();
  };

  return (
    <div className="relative w-full">
      {/* API Error Message */}
      {apiStatus.error && (
        <Alert variant="destructive" className="mb-3">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription className="flex flex-col gap-2">
            <span>
              Google Maps API error: {apiStatus.error}
            </span>
            <Button size="sm" variant="outline" onClick={retryLoading}>
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}
      
      {/* Input field */}
      <div className="relative">
        <Input
          value={input}
          onChange={handleInputChange}
          placeholder={placeholder}
          onFocus={() => input.trim() && apiStatus.loaded && setOpen(true)}
          className="w-full pr-10"
          disabled={apiStatus.loading || !!apiStatus.error}
        />
        <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
          {isLoading || apiStatus.loading ? (
            <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
          ) : (
            <MapPin className="h-4 w-4 text-muted-foreground" />
          )}
        </div>
      </div>

      {/* Dropdown for suggestions */}
      {open && (
        <div className="absolute z-10 mt-1 w-full bg-popover shadow-md rounded-md border">
          {isLoading && suggestions.length === 0 && (
            <div className="p-2 text-sm text-center text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin mx-auto mb-1" />
              Searching...
            </div>
          )}
          
          {!isLoading && suggestions.length === 0 && (
            <div className="p-2 text-sm text-center text-muted-foreground">
              {apiStatus.error ? apiStatus.error : input.length < 2 ? 'Type to search locations' : 'No locations found'}
            </div>
          )}
          
          {suggestions.length > 0 && (
            <ul className="max-h-60 overflow-auto py-1">
              {suggestions.map((location, index) => (
                <li
                  key={index}
                  className="px-2 py-1.5 text-sm hover:bg-accent cursor-pointer flex items-start gap-2"
                  onClick={() => handleSelect(location)}
                >
                  <MapPin className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <div>{location.formattedAddress}</div>
                    {location.postalCode && (
                      <div className="text-xs text-muted-foreground">
                        Postal: {location.postalCode}
                      </div>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}