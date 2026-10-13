
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import * as functions from "firebase-functions/v1";

initializeApp();

export const assignSupabaseRole = functions.auth
  .user()
  .onCreate(async (user) => {
    const auth = getAuth();

    // Preserve existing custom claims, if any.
    const claims = (await auth.getUser(user.uid)).customClaims ?? {};

    await auth.setCustomUserClaims(user.uid, {
      ...claims,
      role: "authenticated",
    });
  });
