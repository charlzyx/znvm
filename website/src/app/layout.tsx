import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { themeBootScript } from "@/lib/theme";

const siteUrl = "https://znvm.dev";

const geist = Geist({
  variable: "--font-geist",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "ZNVM",
    template: "%s | ZNVM",
  },
  description: "NVM and NRM, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
  keywords: ["znvm", "nvm", "nrm", "node version manager", "zig", "npmmirror"],
  authors: [{ name: "charlzyx" }],
  openGraph: {
    title: "ZNVM",
    description: "NVM and NRM, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
    type: "website",
    locale: "en_US",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "ZNVM" }],
    url: siteUrl,
  },
  twitter: {
    card: "summary_large_image",
    title: "ZNVM",
    description: "NVM and NRM, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootScript }} />
      </head>
      <body
        className={`${geist.variable} ${geistMono.variable} antialiased min-h-dvh bg-background font-sans text-foreground`}
      >
        <div className="mx-auto flex min-h-dvh w-full max-w-[1100px] flex-col border-x border-border">
          <Navbar />
          <main className="flex-1">{children}</main>
          <Footer />
        </div>
      </body>
    </html>
  );
}
