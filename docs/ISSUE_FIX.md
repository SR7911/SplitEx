SPLITEX004: 
- Multiple splash screen occurances during login/Siginup/Profile setup flow. This is because the GoRouter instance is being recreated when the auth state changes, causing it to reset to the initialLocation ('/splash'). To fix this, we need to use ref.read instead of ref.watch when creating the GoRouter instance in routerProvider. This way, the GoRouter instance will not be recreated on auth state changes, and it will not reset to the splash screen.


SPLITEX005: 
- Email password sign up error - Somehow fixed
- Adding water in bill not reflecting total - Fixed
- Delete function not available for bills - Fixed
- Activity log not showing for bills - Fixed
- Adding dynamic expense reflects 1- 1 function - Fixed
- Change month, recent activity shows same data - Fixed
- Fresh login steps multiple splash shows - Fixed


SPLITEX006: 
- Added Developer only access to DB & Storage in Home Screen Drawer, 
- Add notification trigger to remind users to settle up
- Refine settlement screen UI with debtor/creditor views
- Implement payment request screen to view, manage, request, and pay settlements
- Add consolidated settlement card showing net position and breakdown
- Add reminder button for creditors using Firestore notifications
- Improve settlement history with cancel/confirm actions and status badges            