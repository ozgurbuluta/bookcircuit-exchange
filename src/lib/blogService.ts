import { db } from './firebase';
import { collection, query, orderBy, limit as limitFn, getDocs, where } from 'firebase/firestore';
import { BlogPost } from './types';

// Get all blog posts
export const getAllBlogPosts = async (): Promise<BlogPost[]> => {
  try {
    const q = query(
      collection(db, 'blogPosts'),
      orderBy('publishedAt', 'desc')
    );

    const snapshot = await getDocs(q);
    const posts = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      published_at: doc.data().publishedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    })) as BlogPost[];

    return processPostsImages(posts);
  } catch (error) {
    console.error('Error fetching blog posts:', error);
    return [];
  }
};

// Get featured blog posts (most recent ones)
export const getFeaturedBlogPosts = async (count: number = 3): Promise<BlogPost[]> => {
  try {
    const q = query(
      collection(db, 'blogPosts'),
      orderBy('publishedAt', 'desc'),
      limitFn(count)
    );

    const snapshot = await getDocs(q);
    const posts = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      published_at: doc.data().publishedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    })) as BlogPost[];

    return processPostsImages(posts);
  } catch (error) {
    console.error('Error fetching featured blog posts:', error);
    return [];
  }
};

// Process post images to ensure they're valid
const processPostsImages = (posts: BlogPost[]): BlogPost[] => {
  return posts.map(post => {
    // Ensure the featured image URL has proper parameters
    if (post.featured_image_url) {
      try {
        // Make sure Unsplash URLs have the right parameters
        if (post.featured_image_url.includes('unsplash.com')) {
          const url = new URL(post.featured_image_url);

          // Ensure we have auto=format and proper quality
          if (!url.searchParams.has('auto')) {
            url.searchParams.set('auto', 'format');
          }

          if (!url.searchParams.has('q')) {
            url.searchParams.set('q', '80');
          }

          // Return the improved URL
          post.featured_image_url = url.toString();
        }
      } catch (e) {
        console.warn('Failed to process image URL for post:', post.title);
      }
    }

    return post;
  });
};

// Get a blog post by slug
export const getBlogPostBySlug = async (slug: string): Promise<BlogPost | null> => {
  try {
    const q = query(
      collection(db, 'blogPosts'),
      where('slug', '==', slug)
    );

    const snapshot = await getDocs(q);

    if (snapshot.empty) {
      return null;
    }

    const doc = snapshot.docs[0];
    const post = {
      id: doc.id,
      ...doc.data(),
      published_at: doc.data().publishedAt?.toDate?.()?.toISOString() || new Date().toISOString(),
    } as BlogPost;

    const posts = processPostsImages([post]);
    return posts[0];
  } catch (error) {
    console.error(`Error fetching blog post with slug ${slug}:`, error);
    return null;
  }
};

// Format a blog post date for display
export const formatBlogDate = (dateString: string): string => {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
};

// Convert markdown content to HTML (basic implementation)
export const markdownToHtml = (markdown: string): string => {
  return markdown
    // Headers
    .replace(/^## (.*$)/gim, '<h2>$1</h2>')
    .replace(/^### (.*$)/gim, '<h3>$1</h3>')
    .replace(/^#### (.*$)/gim, '<h4>$1</h4>')
    // Bold
    .replace(/\*\*(.*?)\*\*/gim, '<strong>$1</strong>')
    // Italic
    .replace(/\*(.*?)\*/gim, '<em>$1</em>')
    // Lists
    .replace(/^- (.*$)/gim, '<li>$1</li>')
    .replace(/<\/li>\n<li>/gim, '</li><li>')
    .replace(/<li>(.*?)<\/li>/gis, '<ul>$&</ul>')
    .replace(/<\/ul>\s*<ul>/gim, '')
    // Links
    .replace(/\[(.*?)\]\((.*?)\)/gim, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>')
    // Line breaks
    .replace(/\n/gim, '<br />');
};
