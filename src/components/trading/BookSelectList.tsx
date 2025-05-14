import { useState, useEffect } from 'react';
import { BookOpen, CheckCircle2 } from 'lucide-react';
import { Book } from '@/lib/types';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Checkbox } from '@/components/ui/checkbox';
import { Badge } from '@/components/ui/badge';

interface BookSelectListProps {
  books: Book[];
  selectedBookIds: string[];
  onSelectionChange: (bookIds: string[]) => void;
  maxHeight?: string;
  emptyMessage?: string;
  disabled?: boolean;
}

export const BookSelectList = ({
  books,
  selectedBookIds,
  onSelectionChange,
  maxHeight = '400px',
  emptyMessage = 'No books available',
  disabled = false,
}: BookSelectListProps) => {
  const toggleBookSelection = (bookId: string) => {
    if (disabled) return;
    
    if (selectedBookIds.includes(bookId)) {
      onSelectionChange(selectedBookIds.filter(id => id !== bookId));
    } else {
      onSelectionChange([...selectedBookIds, bookId]);
    }
  };

  if (books.length === 0) {
    return (
      <div className="p-6 text-center text-muted-foreground border rounded-md">
        {emptyMessage}
      </div>
    );
  }

  return (
    <ScrollArea className="w-full" style={{ maxHeight }}>
      <div className="space-y-2 p-1">
        {books.map((book) => (
          <div
            key={book.id}
            className={`
              flex items-start gap-3 p-3 rounded-md cursor-pointer transition-colors
              ${selectedBookIds.includes(book.id) 
                ? 'bg-muted' 
                : 'hover:bg-muted/40'}
              ${disabled ? 'opacity-70 pointer-events-none' : ''}
            `}
            onClick={() => toggleBookSelection(book.id)}
          >
            {/* Book cover */}
            <div className="flex-shrink-0 w-12 h-16 bg-muted-foreground/10 rounded overflow-hidden border">
              {book.cover_url ? (
                <img
                  src={book.cover_url}
                  alt={book.title}
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    (e.target as HTMLImageElement).src = '/placeholder-book.png';
                  }}
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center">
                  <BookOpen className="h-6 w-6 text-muted-foreground/40" />
                </div>
              )}
            </div>
            
            {/* Book info */}
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h4 className="font-medium text-sm line-clamp-1">{book.title}</h4>
                  {book.author && (
                    <p className="text-xs text-muted-foreground line-clamp-1">
                      by {book.author}
                    </p>
                  )}
                  <Badge 
                    variant="outline"
                    className="mt-1 text-xs"
                  >
                    {book.condition}
                  </Badge>
                </div>
                
                <Checkbox
                  checked={selectedBookIds.includes(book.id)}
                  onCheckedChange={() => toggleBookSelection(book.id)}
                  className="mt-1 data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground"
                  disabled={disabled}
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </ScrollArea>
  );
}; 