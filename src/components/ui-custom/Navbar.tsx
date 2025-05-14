import React, { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Menu, X, User, Loader2, MessageCircle, Repeat } from 'lucide-react';
import Button from './Button';
import { useAuth } from '@/context/AuthContext';
import { supabase } from '@/lib/supabase';
import { TradeNotificationDropdown } from '@/components/trading/TradeNotificationDropdown';

interface UserProfile {
  avatar_url: string | null;
}

const Navbar = () => {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [loadingProfile, setLoadingProfile] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { user, signOut } = useAuth();

  useEffect(() => {
    const handleScroll = () => {
      if (window.scrollY > 10) {
        setIsScrolled(true);
      } else {
        setIsScrolled(false);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    if (user) {
      fetchUserProfile();
      
      // Subscribe to real-time changes on the user's profile
      const profileSubscription = supabase
        .channel('public:profiles')
        .on('postgres_changes', {
          event: 'UPDATE',
          schema: 'public',
          table: 'profiles',
          filter: `id=eq.${user.id}`
        }, (payload) => {
          console.log('Profile updated:', payload);
          if (payload.new && payload.new.avatar_url !== undefined) {
            setUserProfile(payload.new as UserProfile);
          }
        })
        .subscribe();
      
      return () => {
        profileSubscription.unsubscribe();
      };
    } else {
      setUserProfile(null);
    }
  }, [user]);

  const fetchUserProfile = async () => {
    if (!user) return;
    
    try {
      setLoadingProfile(true);
      const { data, error } = await supabase
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .single();
      
      if (error && error.code !== 'PGRST116') {
        console.error('Error fetching profile:', error);
      }
      
      if (data) {
        setUserProfile(data);
      }
    } catch (error: any) {
      console.error('Error:', error.message);
    } finally {
      setLoadingProfile(false);
    }
  };

  const handleSignOut = async () => {
    await signOut();
  };

  const navigateToProfile = () => {
    navigate('/profile');
    if (mobileMenuOpen) {
      setMobileMenuOpen(false);
    }
  };

  const renderUserAvatar = () => {
    if (loadingProfile) {
      return (
        <div className="w-8 h-8 bg-book-accent/10 rounded-full flex items-center justify-center">
          <Loader2 className="w-4 h-4 text-book-accent animate-spin" />
        </div>
      );
    }
    
    if (userProfile?.avatar_url) {
      return (
        <img 
          src={userProfile.avatar_url} 
          alt="Profile" 
          className="w-8 h-8 rounded-full object-cover border border-book-accent/20"
        />
      );
    }
    
    return (
      <div className="w-8 h-8 bg-book-accent/10 rounded-full flex items-center justify-center">
        <User className="w-4 h-4 text-book-accent" />
      </div>
    );
  };

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        isScrolled ? 'py-3 bg-white/80 backdrop-blur-lg shadow-sm' : 'py-5 bg-transparent'
      }`}
    >
      <div className="container px-4 md:px-6 mx-auto">
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <Link to={user ? "/home" : "/"} className="flex items-center space-x-2">
              <span className="text-xl md:text-2xl font-bold font-serif text-book-dark">Turtle Turning Pages</span>
            </Link>
          </div>

          {/* Desktop navigation */}
          <nav className="hidden md:flex items-center space-x-8">
            {!user ? (
              <>
                <a href="#features" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  Features
                </a>
                <a href="#how-it-works" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  How It Works
                </a>
                <a href="#faq" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  FAQ
                </a>
                <Link to="/blog" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  Blog
                </Link>
              </>
            ) : (
              <>
                <Link to="/home" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  Home
                </Link>
                <Link to="/dashboard" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  Dashboard
                </Link>
                <Link to="/chat" className="text-book-dark/80 hover:text-book-accent transition-colors flex items-center">
                  <MessageCircle className="mr-1 h-4 w-4" />
                  Messages
                </Link>
                <Link to="/trades" className="text-book-dark/80 hover:text-book-accent transition-colors flex items-center">
                  <Repeat className="mr-1 h-4 w-4" />
                  Trades
                </Link>
                <Link to="/blog" className="text-book-dark/80 hover:text-book-accent transition-colors">
                  Blog
                </Link>
              </>
            )}
          </nav>

          {/* CTA buttons */}
          <div className="hidden md:flex items-center space-x-4">
            {user ? (
              <>
                <div 
                  className="flex items-center space-x-2 cursor-pointer hover:opacity-80 transition-opacity"
                  onClick={navigateToProfile}
                >
                  {renderUserAvatar()}
                  <span className="text-sm text-book-dark/70 hidden lg:inline-block">
                    {user.email?.split('@')[0]}
                  </span>
                </div>
                <TradeNotificationDropdown />
                <Button variant="outline" size="sm" onClick={handleSignOut}>
                  Sign Out
                </Button>
              </>
            ) : (
              <>
                <Link to="/signin">
                  <Button variant="outline" size="sm">
                    Sign In
                  </Button>
                </Link>
                <Link to="/get-started">
                  <Button variant="primary" size="sm">
                    Get Started
                  </Button>
                </Link>
              </>
            )}
          </div>

          {/* Mobile menu button */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-2 focus:outline-none"
            aria-label="Toggle menu"
          >
            {mobileMenuOpen ? (
              <X className="h-6 w-6 text-book-dark" />
            ) : (
              <Menu className="h-6 w-6 text-book-dark" />
            )}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      <div className={`fixed inset-0 bg-white z-50 transform ${mobileMenuOpen ? 'translate-x-0' : 'translate-x-full'} transition-transform duration-300 ease-in-out md:hidden`}>
        <div className="flex flex-col h-full p-4">
          <div className="flex justify-between items-center mb-8">
            <div className="flex items-center">
              <Link to={user ? "/home" : "/"} className="flex items-center space-x-2" onClick={() => setMobileMenuOpen(false)}>
                <span className="text-xl font-bold font-serif text-book-dark">Turtle Turning Pages</span>
              </Link>
            </div>
            <button
              className="p-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-gray-500 rounded-md"
              onClick={() => setMobileMenuOpen(false)}
            >
              <X className="h-6 w-6 text-gray-500" />
            </button>
          </div>

          <nav className="flex flex-col space-y-4 mt-4">
            {!user ? (
              <>
                <a href="#features" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  Features
                </a>
                <a href="#how-it-works" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  How It Works
                </a>
                <a href="#faq" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  FAQ
                </a>
                <Link to="/blog" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  Blog
                </Link>
              </>
            ) : (
              <>
                <Link to="/home" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  Home
                </Link>
                <Link to="/dashboard" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  Dashboard
                </Link>
                <Link to="/chat" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors flex items-center" onClick={() => setMobileMenuOpen(false)}>
                  <MessageCircle className="mr-2 h-4 w-4" />
                  Messages
                </Link>
                <Link to="/trades" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors flex items-center" onClick={() => setMobileMenuOpen(false)}>
                  <Repeat className="mr-2 h-4 w-4" />
                  Trades
                </Link>
                <Link to="/blog" className="px-2 py-2 text-book-dark/80 hover:text-book-accent transition-colors" onClick={() => setMobileMenuOpen(false)}>
                  Blog
                </Link>
              </>
            )}
          </nav>

          <div className="mt-auto pt-4 border-t">
            {user ? (
              <>
                <div 
                  className="flex items-center space-x-3 mb-4 px-2 py-2 cursor-pointer hover:opacity-80 transition-opacity"
                  onClick={navigateToProfile}
                >
                  {renderUserAvatar()}
                  <span className="text-sm text-book-dark">
                    {user.email}
                  </span>
                </div>
                <TradeNotificationDropdown />
                <Button variant="outline" className="w-full" onClick={handleSignOut}>
                  Sign Out
                </Button>
              </>
            ) : (
              <div className="space-y-2">
                <Link to="/signin">
                  <Button variant="outline" className="w-full" onClick={() => setMobileMenuOpen(false)}>
                    Sign In
                  </Button>
                </Link>
                <Link to="/get-started">
                  <Button variant="primary" className="w-full" onClick={() => setMobileMenuOpen(false)}>
                    Get Started
                  </Button>
                </Link>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};

export default Navbar;
