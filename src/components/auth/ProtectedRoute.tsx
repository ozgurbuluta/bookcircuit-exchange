import { Navigate } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { Loader2 } from "lucide-react";

interface ProtectedRouteProps {
  children: React.ReactNode;
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children }) => {
  const { user, loading, profile } = useAuth();
  
  console.log('DEBUG ProtectedRoute - auth state:', { user, loading, profile });

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen">
        <div className="flex items-center mb-4">
          <Loader2 className="h-8 w-8 animate-spin text-book-accent mr-2" />
          <span className="text-book-dark">Loading...</span>
        </div>
      </div>
    );
  }

  if (!user) {
    console.log("User not authenticated, redirecting to signin");
    return <Navigate to="/signin" replace />;
  }

  console.log("User authenticated, rendering protected content");
  return <>{children}</>;
};

export default ProtectedRoute;
