import './globals.css'

export const metadata = {
  title: 'Basket Coach',
  description: 'PWA for teams, players, plays, and workouts',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <main style={{ maxWidth: 960, margin: '0 auto', padding: 16 }}>
          {children}
        </main>
      </body>
    </html>
  )
}
