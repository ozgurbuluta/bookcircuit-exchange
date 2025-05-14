import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/context/AuthContext";
import ProtectedRoute from "@/components/auth/ProtectedRoute";
import Index from "./pages/Index";
import GetStarted from "./pages/GetStarted";
import SignIn from "./pages/SignIn";
import Dashboard from "./pages/Dashboard";
import Profile from "./pages/Profile";
import AddBook from "./pages/AddBook";
import EditBook from "./pages/EditBook";
import NotFound from "./pages/NotFound";
import Home from "./pages/Home";
import PrivacyPolicy from "./pages/PrivacyPolicy";
import TermsOfService from "./pages/TermsOfService";
import CookiePolicy from "./pages/CookiePolicy";
import SimpleTest from "./pages/SimpleTest";
import Blog from "./pages/Blog";
import BlogPost from "./pages/BlogPost";
import BookDetail from "./pages/BookDetail";
import Chat from "./pages/Chat";
import TradesPage from "./pages/TradesPage";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <BrowserRouter>
        <AuthProvider>
          <Toaster />
          <Sonner />
          <Routes>
            <Route path="/" element={<Index />} />
            <Route path="/get-started" element={<GetStarted />} />
            <Route path="/signin" element={<SignIn />} />
            <Route path="/home" element={
              <ProtectedRoute>
                <Home />
              </ProtectedRoute>
            } />
            <Route path="/dashboard" element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            } />
            <Route path="/profile" element={
              <ProtectedRoute>
                <Profile />
              </ProtectedRoute>
            } />
            <Route path="/add-book" element={
              <ProtectedRoute>
                <AddBook />
              </ProtectedRoute>
            } />
            <Route path="/edit-book/:id" element={
              <ProtectedRoute>
                <EditBook />
              </ProtectedRoute>
            } />
            <Route path="/books/:id" element={<BookDetail />} />
            <Route path="/chat" element={
              <ProtectedRoute>
                <Chat />
              </ProtectedRoute>
            } />
            <Route path="/chat/:conversationId" element={
              <ProtectedRoute>
                <Chat />
              </ProtectedRoute>
            } />
            <Route path="/trades" element={
              <ProtectedRoute>
                <TradesPage />
              </ProtectedRoute>
            } />
            <Route path="/trades/:tradeId" element={
              <ProtectedRoute>
                <TradesPage />
              </ProtectedRoute>
            } />
            <Route path="/simple-test" element={<SimpleTest />} />
            <Route path="/blog" element={<Blog />} />
            <Route path="/blog/:slug" element={<BlogPost />} />
            <Route path="/privacy-policy" element={<PrivacyPolicy />} />
            <Route path="/terms-of-service" element={<TermsOfService />} />
            <Route path="/cookie-policy" element={<CookiePolicy />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
