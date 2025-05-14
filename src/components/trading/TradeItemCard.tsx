import { BookOpen } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';

export interface TradeItem {
  id: string;
  book_id: string;
  title: string;
  author?: string;
  cover_url?: string;
  condition?: string;
  owner_id: string;
  owner_name?: string;
  item_type: 'book';
}

interface TradeItemCardProps {
  item: TradeItem;
  isUser?: boolean;
  selected?: boolean;
  onClick?: () => void;
  className?: string;
  showOwner?: boolean;
}

export function TradeItemCard({
  item,
  isUser = false,
  selected = false,
  onClick,
  className,
  showOwner = false,
}: TradeItemCardProps) {
  const isSelectable = !!onClick;
  
  return (
    <div
      className={cn(
        "group border rounded-lg overflow-hidden transition-all",
        isSelectable && "cursor-pointer hover:border-primary",
        selected && "ring-2 ring-primary border-primary",
        className
      )}
      onClick={onClick}
    >
      <div className="flex gap-3 p-3">
        <div className="flex-shrink-0 w-16 h-20 bg-muted rounded overflow-hidden">
          {item.cover_url ? (
            <img
              src={item.cover_url}
              alt={item.title}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <BookOpen className="h-8 w-8 text-muted-foreground/40" />
            </div>
          )}
        </div>
        
        <div className="flex flex-col flex-grow">
          <div className="flex flex-col">
            <h3 className="font-medium line-clamp-2">{item.title}</h3>
            {item.author && (
              <p className="text-sm text-muted-foreground">{item.author}</p>
            )}
          </div>
          
          <div className="mt-auto flex flex-wrap gap-2 items-center pt-1">
            {item.condition && (
              <Badge variant="outline" className="text-xs">
                {item.condition}
              </Badge>
            )}
            
            {showOwner && item.owner_name && (
              <span className="text-xs text-muted-foreground">
                Owned by {item.owner_name}
              </span>
            )}
            
            {isUser && (
              <Badge variant="secondary" className="text-xs">
                Your book
              </Badge>
            )}
          </div>
        </div>
      </div>
    </div>
  );
} 