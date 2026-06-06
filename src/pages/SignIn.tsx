import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { Eye, EyeOff } from 'lucide-react';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import Button from '@/components/ui-custom/Button';
import { useAuth } from '@/context/AuthContext';

const SignIn = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isResettingPassword, setIsResettingPassword] = useState(false);
  const { signIn, resetPassword } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const from = (location.state as { from?: { pathname: string } })?.from?.pathname || '/home';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!email || !password) return;
    
    try {
      setIsLoading(true);
      await signIn(email, password);
      navigate(from, { replace: true });
    } catch (error) {
      console.error("Error signing in:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      
      <main className="flex-grow pt-28 pb-20">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-md mx-auto">
            <div className="text-center mb-8">
              <h1 className="text-3xl font-bold font-serif mb-2">Welcome Back</h1>
              <p className="text-book-dark/70">
                Sign in to continue your book trading journey
              </p>
            </div>
            
            <div className="glass-card rounded-xl p-8 shadow-lg">
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
                </div>
                
                <div className="flex items-center justify-between">
                  <div className="flex items-center">
                    <input
                      id="remember-me"
                      name="remember-me"
                      type="checkbox"
                      className="h-4 w-4 rounded border-book-accent/20 text-book-accent focus:ring-book-accent/50"
                      disabled={isLoading}
                    />
                    <label htmlFor="remember-me" className="ml-2 block text-sm text-book-dark/70">
                      Remember me
                    </label>
                  </div>
                  
                  <div className="text-sm">
                    <button
                      type="button"
                      onClick={async () => {
                        if (!email) {
                          alert('Please enter your email address first.');
                          return;
                        }
                        setIsResettingPassword(true);
                        await resetPassword(email);
                        setIsResettingPassword(false);
                      }}
                      disabled={isResettingPassword}
                      className="text-book-accent hover:underline"
                    >
                      {isResettingPassword ? 'Sending...' : 'Forgot password?'}
                    </button>
                  </div>
                </div>
                
                <Button 
                  type="submit" 
                  variant="primary" 
                  size="lg" 
                  fullWidth
                  disabled={isLoading}
                >
                  {isLoading ? 'Signing in...' : 'Sign In'}
                </Button>
              </form>
              
              <div className="mt-6">
                <div className="relative">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-book-accent/10"></div>
                  </div>
                  <div className="relative flex justify-center text-sm">
                    <span className="px-2 bg-white text-book-dark/60">Or continue with</span>
                  </div>
                </div>
                
                <div className="mt-6 grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    className="w-full inline-flex justify-center py-2 px-4 border border-book-accent/20 rounded-md shadow-sm bg-white text-sm font-medium text-book-dark hover:bg-book-accent/5"
                    disabled={isLoading}
                  >
                    <span className="sr-only">Sign in with Google</span>
                    <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12.545,12.151L12.545,12.151c0,1.054,0.855,1.909,1.909,1.909h3.536c-0.684,1.885-2.292,3.494-4.177,4.177 C10.922,19.145,7.849,18.185,6,15.727V15.727c-0.144-0.194-0.342-0.346-0.572-0.427C4.23,14.862,3.453,15.21,3.115,16 c-0.338,0.79,0.01,1.821,0.8,2.16c0.142,0.061,0.294,0.091,0.448,0.091c0.344,0,0.68-0.132,0.92-0.372 C6.273,20.09,8.963,22,12,22c6.075,0,11-4.925,11-11v-0.545c0-1.054-0.855-1.909-1.909-1.909h-6.545 c-1.054,0-1.909,0.855-1.909,1.909C12.636,10.455,12.545,12.151,12.545,12.151z M23,10c0-4.963-4.037-9-9-9 c-3.489,0-6.514,1.99-8,4.899l5.625-1.262c0.839-0.188,1.75,0.086,2.304,0.639c0.554,0.554,0.828,1.465,0.639,2.305 L12.454,9H22.5C22.776,9,23,9.224,23,9.5V10z" />
                    </svg>
                  </button>
                  
                  <button
                    type="button"
                    className="w-full inline-flex justify-center py-2 px-4 border border-book-accent/20 rounded-md shadow-sm bg-white text-sm font-medium text-book-dark hover:bg-book-accent/5"
                    disabled={isLoading}
                  >
                    <span className="sr-only">Sign in with Facebook</span>
                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                      <path fillRule="evenodd" d="M22 12c0-5.523-4.477-10-10-10S2 6.477 2 12c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V12h2.54V9.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V12h2.773l-.443 2.89h-2.33v6.988C18.343 21.128 22 16.991 22 12z" clipRule="evenodd" />
                    </svg>
                  </button>
                </div>
              </div>
              
              <div className="mt-6 text-center text-sm text-book-dark/60">
                Don't have an account?{' '}
                <Link to="/get-started" className="text-book-accent hover:underline">
                  Create one
                </Link>
              </div>
            </div>
          </div>
        </div>
      </main>
      
      <Footer />
    </div>
  );
};

export default SignIn;
