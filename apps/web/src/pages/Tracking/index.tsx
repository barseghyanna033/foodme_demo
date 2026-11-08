import { useState } from "react";
import { useParams, Link } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Ban, Check, ChefHat, Package, Truck, X } from "lucide-react";
import { foodmeApi } from "@/api/foodme";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/dialog";
import { formatAmd } from "@/lib/utils";
import { useAuth } from "@/providers/auth-provider";

const STEPS = [
  { key: "NEW", label: "Received", Icon: Package },
  { key: "ACCEPTED", label: "Preparing", Icon: ChefHat },
  { key: "DELIVERED", label: "Delivered", Icon: Truck },
] as const;

const STATUS_COPY: Record<string, { title: string; detail: string }> = {
  NEW: {
    title: "Order received",
    detail: "The kitchen has your order and will confirm shortly.",
  },
  ACCEPTED: {
    title: "Preparing your order",
    detail: "Your chef is cooking. We’ll mark it delivered when it’s on the way.",
  },
  DELIVERED: {
    title: "Delivered",
    detail: "Enjoy your meal. Hope it hit the spot.",
  },
  REJECTED: {
    title: "Order declined",
    detail: "This order couldn’t be fulfilled. Contact support if you need help.",
  },
  CANCELLED: {
    title: "Order cancelled",
    detail: "You cancelled this order before the kitchen accepted it.",
  },
};

function stepIndex(status: string): number {
  if (status === "REJECTED" || status === "CANCELLED") return -1;
  const i = STEPS.findIndex((s) => s.key === status);
  return i >= 0 ? i : 0;
}

export default function Tracking() {
  const { number } = useParams<{ number: string }>();
  const { isAuthenticated, customer } = useAuth();

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["order", number],
    queryFn: () => foodmeApi.getOrderByNumber(number as string),
    enabled: !!number,
  });

  // Tracking links are public, so check ownership before offering cancellation.
  const ownership = useQuery({
    queryKey: ["my-order", number, customer?.id],
    queryFn: () => foodmeApi.getMyOrder(number as string),
    enabled: isAuthenticated && !!number && data?.status === "NEW",
    retry: false,
  });

  const queryClient = useQueryClient();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const cancelOrder = useMutation({
    mutationFn: () => foodmeApi.cancelMyOrder(number as string),
    onSuccess: (order) => {
      queryClient.setQueryData(["order", number], order);
      void queryClient.invalidateQueries({ queryKey: ["my-orders"] });
      setConfirmOpen(false);
    },
    onError: () => {
      // The kitchen may have accepted the order meanwhile; show its real status.
      setConfirmOpen(false);
      void refetch();
    },
  });

  if (isLoading) {
    return (
      <div
        className="mx-auto max-w-xl px-4 py-16"
        aria-label="Loading order status"
        aria-live="polite"
      >
        <div className="h-8 w-48 animate-pulse rounded-lg bg-zinc-100" />
        <div className="mt-6 h-28 animate-pulse rounded-[1.5rem] bg-zinc-100" />
        <div className="mt-4 h-40 animate-pulse rounded-[1.5rem] bg-zinc-100" />
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="mx-auto max-w-md px-4 py-20 text-center">
        <p className="font-display text-xl font-bold text-zinc-900">Couldn’t load this order</p>
        <p className="mt-2 text-sm text-zinc-500">
          Check the order number, or retry if your connection was interrupted.
        </p>
        <div className="mt-6 flex justify-center gap-2">
          <Button className="rounded-full" onClick={() => void refetch()}>
            Try again
          </Button>
          <Button asChild className="rounded-full" variant="outline">
            <Link to="/explore">Back to explore</Link>
          </Button>
        </div>
      </div>
    );
  }

  const copy = STATUS_COPY[data.status] ?? {
    title: data.status,
    detail: "Current status for your order.",
  };
  const active = stepIndex(data.status);
  const rejected = data.status === "REJECTED";
  const cancelled = data.status === "CANCELLED";
  // The backend also enforces ownership and NEW status; this only decides visibility.
  const canCancel = isAuthenticated && data.status === "NEW" && ownership.isSuccess;

  return (
    <div className="tp_wrap mx-auto max-w-7xl px-4 py-10 md:px-8 md:py-14">
      <div className="mx-auto max-w-xl">
      <div className="animate-fade-up">
        <h1 className="font-display text-3xl font-extrabold tracking-tight text-zinc-900">
          Order {data.number}
        </h1>
        <p className="mt-1.5 text-sm text-zinc-500">Chef · {data.chefName}</p>
        {isAuthenticated && (
          <Link to="/orders" className="mt-3 inline-block text-sm font-semibold text-zinc-900 underline-offset-4 hover:underline">
            All orders
          </Link>
        )}
      </div>

      <div className="bezel-outer shadow-diffuse mt-8 animate-fade-up [animation-delay:60ms]">
        <div className="bezel-inner p-5 md:p-6">
          {rejected || cancelled ? (
            <div className="flex items-start gap-3">
              <div
                className={[
                  "flex h-10 w-10 shrink-0 items-center justify-center rounded-full ring-1",
                  cancelled
                    ? "bg-zinc-100 text-zinc-600 ring-zinc-200"
                    : "bg-red-50 text-red-600 ring-red-100",
                ].join(" ")}
              >
                {cancelled ? <Ban size={18} strokeWidth={2} /> : <X size={18} strokeWidth={2} />}
              </div>
              <div>
                <p className="font-display text-lg font-bold text-zinc-900">{copy.title}</p>
                <p className="mt-1 text-sm leading-relaxed text-zinc-500">{copy.detail}</p>
              </div>
            </div>
          ) : (
            <>
              <div className="mb-6">
                <p className="font-display text-lg font-bold text-zinc-900">{copy.title}</p>
                <p className="mt-1 text-sm leading-relaxed text-zinc-500">{copy.detail}</p>
              </div>

              <ol className="relative grid grid-cols-3 gap-2">
                {/* Connector centered on circle midpoints (h-11 → top 22px) */}
                <div
                  className="pointer-events-none absolute left-[calc(100%/6)] right-[calc(100%/6)] top-[22px] z-0 h-0.5 -translate-y-1/2 overflow-hidden rounded-full bg-zinc-100"
                  aria-hidden="true"
                >
                  <div
                    className="h-full bg-zinc-900 transition-all duration-700 ease-[cubic-bezier(0.32,0.72,0,1)]"
                    style={{
                      width: active <= 0 ? "0%" : active >= 2 ? "100%" : "50%",
                    }}
                  />
                </div>
                {STEPS.map(({ key, label, Icon }, index) => {
                  const done = index <= active;
                  const current = index === active;
                  return (
                    <li key={key} className="relative z-10 flex flex-col items-center text-center">
                      <span
                        aria-current={current ? "step" : undefined}
                        className={[
                          "flex h-11 w-11 items-center justify-center rounded-full",
                          "transition-all duration-500 ease-[cubic-bezier(0.32,0.72,0,1)]",
                          done
                            ? "bg-zinc-900 text-white shadow-[0_10px_24px_-12px_rgba(28,25,23,0.35)]"
                            : "bg-zinc-100 text-zinc-400 ring-1 ring-zinc-200/80",
                          current ? "scale-105 ring-4 ring-zinc-900/10" : "",
                        ].join(" ")}
                      >
                        {done && index < active ? (
                          <Check size={16} strokeWidth={2.5} />
                        ) : (
                          <Icon size={16} strokeWidth={1.75} />
                        )}
                      </span>
                      <span
                        className={[
                          "mt-2.5 text-[11px] font-semibold",
                          done ? "text-zinc-800" : "text-zinc-400",
                        ].join(" ")}
                      >
                        {label}
                      </span>
                    </li>
                  );
                })}
              </ol>

              {canCancel && (
                <div className="mt-6 border-t border-zinc-100 pt-5">
                  <p className="text-sm text-zinc-500">
                    Changed your mind? You can cancel until the kitchen accepts the order.
                  </p>
                  <Button
                    variant="outline"
                    className="mt-3 rounded-full border-red-200 text-red-700 hover:bg-red-50"
                    onClick={() => {
                      cancelOrder.reset();
                      setConfirmOpen(true);
                    }}
                  >
                    Cancel order
                  </Button>
                </div>
              )}
            </>
          )}

          {cancelOrder.isError && (
            <p role="alert" className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
              Couldn’t cancel this order: {cancelOrder.error.message}
            </p>
          )}
        </div>
      </div>

      <Dialog open={confirmOpen} onOpenChange={(open) => !cancelOrder.isPending && setConfirmOpen(open)}>
        <DialogContent className="max-w-sm p-6">
          <DialogTitle className="font-display text-xl font-bold text-zinc-900">
            Cancel order {data.number}?
          </DialogTitle>
          <DialogDescription className="mt-2 text-sm leading-relaxed text-zinc-500">
            The kitchen won’t prepare it. This can’t be undone.
          </DialogDescription>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <DialogClose asChild>
              <Button variant="outline" className="rounded-full" disabled={cancelOrder.isPending}>
                Keep order
              </Button>
            </DialogClose>
            <Button
              className="rounded-full bg-red-600 text-white hover:bg-red-700"
              disabled={cancelOrder.isPending}
              onClick={() => cancelOrder.mutate()}
            >
              {cancelOrder.isPending ? "Cancelling…" : "Yes, cancel order"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      <div className="bezel-outer shadow-diffuse mt-5 animate-fade-up [animation-delay:120ms]">
        <div className="bezel-inner overflow-hidden">
          <div className="border-b border-zinc-100 px-5 py-3.5">
            <p className="text-base font-bold text-zinc-900">Items</p>
          </div>
          <div className="divide-y divide-zinc-100">
            {/* The tracking DTO's dish rows carry no id; the list is static for
                a given order, so a name+index key is stable. */}
            {data.orderDishList.map((dish, index) => (
              <div
                key={`${dish.nameEn}-${index}`}
                className="flex items-center justify-between gap-4 px-5 py-3.5 text-sm"
              >
                <span className="min-w-0 break-words text-zinc-800">
                  <span className="tabular-nums text-zinc-400">{dish.quantity}</span>
                  <span className="mx-1.5 text-zinc-300">&times;</span>
                  {dish.nameEn}
                </span>
                <span className="font-semibold tabular-nums text-zinc-800">
                  {formatAmd(dish.price * dish.quantity)}
                </span>
              </div>
            ))}
          </div>
          <div className="flex items-end justify-between border-t border-zinc-100 bg-zinc-50/50 px-5 py-4">
            <span className="text-sm font-bold text-zinc-900">Total</span>
            <span className="font-display text-xl font-bold tabular-nums text-zinc-900">
              {formatAmd(data.totalPrice)}
            </span>
          </div>
        </div>
      </div>
      </div>
    </div>
  );
}
