import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { User, Book, Map, MessageCircle, Eye, EyeOff } from 'lucide-react';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import Button from '@/components/ui-custom/Button';
import { useAuth } from '@/context/AuthContext';

const GetStarted = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const { signUp, user, loading } = useAuth();
  const navigate = useNavigate();

  // Redirect if user is already logged in
  useEffect(() => {
    if (user && !loading) {
      navigate('/home');
    }
  }, [user, loading, navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!email || !password) return;

    try {
      setIsLoading(true);
      const result = await signUp(email, password);
      // Firebase signs in immediately after signup
      // The AuthContext will navigate to dashboard on success
      if (!result.success) {
        // Error already shown via toast in AuthContext
      }
    } catch (error) {
      console.error("Error signing up:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      
      <main className="flex-grow pt-28 pb-20">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-3xl mx-auto">
                <div className="text-center mb-10">
                  <h1 className="text-3xl md:text-4xl font-bold font-serif mb-4">Join Turtle Turning Pages Today</h1>
                  <p className="text-book-dark/70 text-lg">
                    Create your account to start trading books with readers in your community.
                  </p>
                </div>
                
                <div className="glass-card rounded-xl p-8 shadow-lg mb-10">
                  <form onSubmit={handleSubmit} className="space-y-6">
                    <div>
                      <label htmlFor="email" className="block text-sm font-medium mb-2">Email Address</label>
                      <input
                        id="email"
                        type="email"
                        className="w-full px-4 py-2 rounded-lg border border-book-accent/20 focus:outline-none focus:ring-2 focus:ring-book-accent/50"
                        placeholder="you@example.com"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        disabled={isLoading}
                      />
                    </div>
                    
                    <div>
                      <label htmlFor="password" className="block text-sm font-medium mb-2">Password</label>
                      <div className="relative">
                        <input
                          id="password"
                          type={showPassword ? "text" : "password"}
                          className="w-full px-4 py-2 rounded-lg border border-book-accent/20 focus:outline-none focus:ring-2 focus:ring-book-accent/50"
                          placeholder="••••••••"
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          required
                          disabled={isLoading}
                          minLength={6}
                        />
                        <button
                          type="button"
                          className="absolute right-3 top-1/2 transform -translate-y-1/2 text-book-dark/50"
                          onClick={() => setShowPassword(!showPassword)}
                          disabled={isLoading}
                        >
                          {showPassword ? (
                            <EyeOff className="w-5 h-5" />
                          ) : (
                            <Eye className="w-5 h-5" />
                          )}
                        </button>
                      </div>
                      <p className="text-xs text-book-dark/60 mt-1">
                        Password must be at least 6 characters long
                      </p>
                    </div>
                    
                    <Button 
                      type="submit" 
                      variant="primary" 
                      size="lg" 
                      fullWidth
                      disabled={isLoading}
                    >
                      {isLoading ? 'Creating account...' : 'Get Early Access'}
                    </Button>
                  </form>
                  
                  <div className="mt-4 text-center text-sm text-book-dark/60">
                    Already have an account? <Link to="/signin" className="text-book-accent hover:underline">Sign in</Link>
                  </div>
                </div>
                
                <div className="space-y-8">
                  <h2 className="text-2xl font-bold font-serif text-center">Why Join Turtle Turning Pages?</h2>
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="flex items-start space-x-3">
                      <div className="mt-1 bg-book-accent/10 p-2 rounded-full">
                        <Book className="w-5 h-5 text-book-accent" />
                      </div>
                      <div>
                        <h3 className="font-medium mb-1">Access More Books</h3>
                        <p className="text-book-dark/70 text-sm">Trade books you've read for ones you want to read.</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start space-x-3">
                      <div className="mt-1 bg-book-accent/10 p-2 rounded-full">
                        <Map className="w-5 h-5 text-book-accent" />
                      </div>
                      <div>
                        <h3 className="font-medium mb-1">Local Community</h3>
                        <p className="text-book-dark/70 text-sm">Connect with readers who live near you.</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start space-x-3">
                      <div className="mt-1 bg-book-accent/10 p-2 rounded-full">
                        <User className="w-5 h-5 text-book-accent" />
                      </div>
                      <div>
                        <h3 className="font-medium mb-1">Reader Profiles</h3>
                        <p className="text-book-dark/70 text-sm">Share your reading tastes and discover similar readers.</p>
                      </div>
                    </div>
                    
                    <div className="flex items-start space-x-3">
                      <div className="mt-1 bg-book-accent/10 p-2 rounded-full">
                        <MessageCircle className="w-5 h-5 text-book-accent" />
                      </div>
                      <div>
                        <h3 className="font-medium mb-1">Safe Messaging</h3>
                        <p className="text-book-dark/70 text-sm">Communicate directly with other readers.</p>
                      </div>
                    </div>
                  </div>
                </div>
          </div>
        </div>
      </main>
      
      <Footer />
    </div>
  );
};

export default GetStarted;
