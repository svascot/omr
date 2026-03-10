# Multi-Tenant Architecture Plan

To transition the app into a multi-tenant system with a backend, we need to design an architecture that connects the iOS app to a centralized API, handles secure authentication, and manages data across different databases. 

Here is a high-level breakdown of the necessary components and best practices for building it using Vercel, a Node/TypeScript Monolith, PostgreSQL (RDS), MongoDB, and OAuth.

## 1. The Backend (Node.js/TypeScript Monolith on Vercel)
Vercel handles serverless functions effectively. By building a "monolith" codebase, Vercel will deploy your API routes as isolated serverless functions under the hood. 

**Recommended Tech Stack:**
*   **Framework:** **Next.js** (API Routes) or **Express/NestJS** wrapped for Vercel. Next.js API routes are typically the easiest and most native way to build an API on Vercel.
*   **Language:** **TypeScript** (for type safety between database models and API responses).
*   **ORM for RDS (PostgreSQL/MySQL):** **Prisma** or **Drizzle**. These are excellent for managing relational user data, roles, and billing/subscription information.
*   **ODM for MongoDB:** **Mongoose** or the native MongoDB Node Driver. This is where high-volume, flexible data like `SessionStats` (reps, duration, video metadata, etc.) will be stored.

## 2. Authentication & Identity (Gmail/Apple Login)
Handling OAuth securely is complex, especially when planning for both Mobile and Web.

**Recommended Approach:** Use an Identity Provider (IdP) like **Supabase Auth**, **Clerk**, or **Auth0**.
*   **Why?** They handle the complexity of "Sign in with Apple" (which has strict requirements from Apple) and Google OAuth out of the box. They also issue secure JWTs (JSON Web Tokens) that the backend can verify.
*   **The Flow:**
    1. The iOS app uses the IdP's SDK (e.g., Supabase Swift SDK) to authenticate the user via Apple/Google.
    2. The app receives a JWT.
    3. The app includes this JWT in the `Authorization: Bearer <token>` header of every API request made to the Vercel backend.
    4. The Vercel backend verifies the JWT. If valid, it extracts the `userId` and queries the RDS/Mongo databases.

## 3. Database Architecture Strategy
Splitting data between RDS and MongoDB is a common pattern for scalability:

**RDS (PostgreSQL): The "Source of Truth" & Multi-Tenancy**
*   **Tables:** `Users`, `Tenants/Workspaces` (if users can form groups/teams later), `Subscriptions`, `Roles`.
*   *Why RDS?* You need strict relational constraints for billing, identity, and access control.

**MongoDB: Analytics & Events**
*   **Collections:** `TrainingSessions` (the JSON data currently stored locally), `MovementMetrics`.
*   *Why Mongo?* As movement tracking gets more advanced, the data shape of a "Session" might change frequently. Document databases handle this schema-less evolution well.
*   *Linking the two:* Every document in MongoDB should have a `userId` field that matches the UUID of the user in the RDS database.

## 4. iOS App Updates (SwiftUI)
To connect the current app to the new backend, the local `FileManager` storage logic in `AppState.swift` needs to be replaced with network requests.

**Required Swift Updates:**
1.  **Authentication UI:** Add a login screen with "Sign in with Apple" (`AuthenticationServices` framework) and "Sign in with Google".
2.  **API Client:** Build a network layer (using `URLSession` or a library like `Alamofire`) to communicate with the Vercel API.
3.  **State Synchronization:** When the app opens, fetch the user's history from the backend. When a session finishes (`endTraining`), send a `POST` request to the backend to save the session to MongoDB, rather than writing to the local `user_data_v2.json`.

## 5. Video Storage (Crucial for this app)
Currently, videos are saved locally to the user's camera roll. For a true multi-tenant cloud experience where users can view their videos on the web later, video files cannot be stored directly in MongoDB or RDS.

**The Solution:** Object Storage (AWS S3)
*   When a user finishes a session, the iOS app requests a "Presigned URL" from the Vercel backend.
*   The Vercel backend generates a secure, temporary URL to an S3 bucket and returns it to the app.
*   The iOS app uploads the video directly to S3 using that URL.
*   Once uploaded, the app sends the resulting S3 Video URL to the Vercel backend along with the `SessionStats` to be saved in MongoDB.

## Summary: Action Plan
Chronological order for building this architecture:
1.  **Set up Vercel + Backend:** Initialize a Next.js or Express repo. Connect it to a free PostgreSQL database (like Supabase or Neon) and a free MongoDB Atlas cluster.
2.  **Set up Auth:** Integrate Clerk or Supabase Auth. Create test API routes that require a valid token.
3.  **Update the iOS App:** Add the login screen to the Swift app and successfully get an auth token.
4.  **Migrate Data Logic:** Rewrite the `endTraining` and `loadData` functions in `AppState.swift` to make HTTP requests to the new backend instead of reading/writing local JSON.
