import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { getConversationById } from '@/lib/conversationService';
import ChatContainer from '../components/chat/ChatContainer';
import Navbar from '@/components/ui-custom/Navbar';
import Footer from '@/components/ui-custom/Footer';
import { Helmet } from 'react-helmet';
import { Button } from '../components/ui/button';
import { ArrowLeft } from 'lucide-react';

const Chat = () => {
  const { conversationId } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasAccess, setHasAccess] = useState(false);

  useEffect(() => {
    if (!user) {
      navigate('/signin');
      return;
    }

    const checkAccess = async () => {
      setLoading(true);
      try {
        // If no conversationId is provided, just show all conversations
        if (!conversationId) {
          setHasAccess(true);
          setLoading(false);
          return;
        }

        // Check if user has access to this conversation
        const conversation = await getConversationById(conversationId);
        setHasAccess(conversation !== null);
      } catch (err: any) {
        console.error('Error checking conversation access:', err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    checkAccess();
  }, [user, conversationId, navigate]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-book-paper">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-book-leather"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-screen bg-book-paper p-4 text-center">
        <h1 className="text-2xl font-bold text-book-accent mb-4">Error</h1>
        <p className="text-book-dark mb-6">{error}</p>
        <Button onClick={() => navigate(-1)} className="bg-book-leather text-white hover:bg-book-leather/90">Go Back</Button>
      </div>
    );
  }

  if (!hasAccess && conversationId) {
    return (
      <div className="flex flex-col items-center justify-center h-screen bg-book-paper p-4 text-center">
        <h1 className="text-2xl font-bold text-book-accent mb-4">Access Denied</h1>
        <p className="text-book-dark mb-6">
          You don't have access to this conversation or it doesn't exist.
        </p>
        <Button onClick={() => navigate('/chat')} className="bg-book-leather text-white hover:bg-book-leather/90">Go to My Conversations</Button>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-book-paper">
      <Helmet>
        <title>Chat | Turtle Turning Pages</title>
      </Helmet>

      <Navbar />

      <main className="flex-grow pt-28 pb-20">
        <div className="container mx-auto px-4 md:px-6">
          <div className="max-w-6xl mx-auto bg-white rounded-lg shadow-md overflow-hidden border border-book-leather/10">
            <div className="flex items-center p-4 border-b border-book-leather/10">
              <Button
                variant="ghost"
                className="p-0 mr-2 text-book-dark hover:text-book-dark/70 hover:bg-transparent"
                onClick={() => navigate(-1)}
              >
                <ArrowLeft className="h-6 w-6" />
              </Button>
              <h1 className="text-2xl font-bold text-book-leather">Messages</h1>
            </div>

            <ChatContainer userId={user?.uid} selectedConversationId={conversationId} />
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default Chat;
