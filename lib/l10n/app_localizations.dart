import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TranZfort'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobile;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @joinNetwork.
  ///
  /// In en, this message translates to:
  /// **'Join India\'s trucking network'**
  String get joinNetwork;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @myLoads.
  ///
  /// In en, this message translates to:
  /// **'My Loads'**
  String get myLoads;

  /// No description provided for @postLoad.
  ///
  /// In en, this message translates to:
  /// **'Post New Load'**
  String get postLoad;

  /// No description provided for @findLoads.
  ///
  /// In en, this message translates to:
  /// **'Find Loads'**
  String get findLoads;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTrips;

  /// No description provided for @myFleet.
  ///
  /// In en, this message translates to:
  /// **'My Fleet'**
  String get myFleet;

  /// No description provided for @addTruck.
  ///
  /// In en, this message translates to:
  /// **'Add Truck'**
  String get addTruck;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profile;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @superLoad.
  ///
  /// In en, this message translates to:
  /// **'Super Load'**
  String get superLoad;

  /// No description provided for @superDashboard.
  ///
  /// In en, this message translates to:
  /// **'Super Loads'**
  String get superDashboard;

  /// No description provided for @payoutProfile.
  ///
  /// In en, this message translates to:
  /// **'Payout Profile'**
  String get payoutProfile;

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @trucker.
  ///
  /// In en, this message translates to:
  /// **'Trucker'**
  String get trucker;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @material.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get material;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @pickupDate.
  ///
  /// In en, this message translates to:
  /// **'Pickup Date'**
  String get pickupDate;

  /// No description provided for @truckType.
  ///
  /// In en, this message translates to:
  /// **'Truck Type'**
  String get truckType;

  /// No description provided for @tyres.
  ///
  /// In en, this message translates to:
  /// **'Tyres'**
  String get tyres;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @switchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch Role'**
  String get switchRole;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @chatNow.
  ///
  /// In en, this message translates to:
  /// **'Chat Now'**
  String get chatNow;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get sendMessage;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noMessages;

  /// No description provided for @tonnes.
  ///
  /// In en, this message translates to:
  /// **'tonnes'**
  String get tonnes;

  /// No description provided for @enterMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your 10-digit mobile number'**
  String get enterMobileNumber;

  /// No description provided for @enterEmailOrMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter email or mobile number'**
  String get enterEmailOrMobile;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to {number}'**
  String otpSentTo(String number);

  /// No description provided for @didntReceiveOtp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive OTP?'**
  String get didntReceiveOtp;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @otpExpired.
  ///
  /// In en, this message translates to:
  /// **'OTP has expired'**
  String get otpExpired;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// No description provided for @accountLocked.
  ///
  /// In en, this message translates to:
  /// **'Account temporarily locked. Try again later.'**
  String get accountLocked;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get passwordResetEmailSent;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @agreeTo.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get agreeTo;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @accountCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please confirm your email, then log in.'**
  String get accountCreatedSuccess;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordRequirements;

  /// No description provided for @roleSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'What describes you best?'**
  String get roleSelectionTitle;

  /// No description provided for @roleSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role to get started'**
  String get roleSelectionSubtitle;

  /// No description provided for @iAmSupplier.
  ///
  /// In en, this message translates to:
  /// **'I am a Supplier'**
  String get iAmSupplier;

  /// No description provided for @iAmTrucker.
  ///
  /// In en, this message translates to:
  /// **'I am a Trucker'**
  String get iAmTrucker;

  /// No description provided for @supplierSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Post Loads, Find Trucks, Track Deliveries'**
  String get supplierSubtitle;

  /// No description provided for @truckerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find Loads, Manage Fleet, Get Paid'**
  String get truckerSubtitle;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(String name);

  /// No description provided for @completeVerification.
  ///
  /// In en, this message translates to:
  /// **'Complete verification to post loads'**
  String get completeVerification;

  /// No description provided for @activeLoads.
  ///
  /// In en, this message translates to:
  /// **'Active Loads'**
  String get activeLoads;

  /// No description provided for @completedLoads.
  ///
  /// In en, this message translates to:
  /// **'Completed Loads'**
  String get completedLoads;

  /// No description provided for @totalLoads.
  ///
  /// In en, this message translates to:
  /// **'Total Loads'**
  String get totalLoads;

  /// No description provided for @recentLoads.
  ///
  /// In en, this message translates to:
  /// **'Recent Loads'**
  String get recentLoads;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @postYourFirstLoad.
  ///
  /// In en, this message translates to:
  /// **'Post your first load'**
  String get postYourFirstLoad;

  /// No description provided for @noActiveLoads.
  ///
  /// In en, this message translates to:
  /// **'No active loads'**
  String get noActiveLoads;

  /// No description provided for @noCompletedLoads.
  ///
  /// In en, this message translates to:
  /// **'No completed loads'**
  String get noCompletedLoads;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @postLoadQuick.
  ///
  /// In en, this message translates to:
  /// **'Post a Load'**
  String get postLoadQuick;

  /// No description provided for @viewHistory.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get viewHistory;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @routeDetails.
  ///
  /// In en, this message translates to:
  /// **'Route Details'**
  String get routeDetails;

  /// No description provided for @cargoDetails.
  ///
  /// In en, this message translates to:
  /// **'Cargo Details'**
  String get cargoDetails;

  /// No description provided for @commercialDetails.
  ///
  /// In en, this message translates to:
  /// **'Commercial Details'**
  String get commercialDetails;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @originCity.
  ///
  /// In en, this message translates to:
  /// **'Origin City'**
  String get originCity;

  /// No description provided for @destinationCity.
  ///
  /// In en, this message translates to:
  /// **'Destination City'**
  String get destinationCity;

  /// No description provided for @enterOrigin.
  ///
  /// In en, this message translates to:
  /// **'Enter origin city'**
  String get enterOrigin;

  /// No description provided for @enterDestination.
  ///
  /// In en, this message translates to:
  /// **'Enter destination city'**
  String get enterDestination;

  /// No description provided for @selectOrigin.
  ///
  /// In en, this message translates to:
  /// **'Select origin'**
  String get selectOrigin;

  /// No description provided for @selectDestination.
  ///
  /// In en, this message translates to:
  /// **'Select destination'**
  String get selectDestination;

  /// No description provided for @selectMaterial.
  ///
  /// In en, this message translates to:
  /// **'Select material'**
  String get selectMaterial;

  /// No description provided for @enterWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter weight in tonnes'**
  String get enterWeight;

  /// No description provided for @expectedPrice.
  ///
  /// In en, this message translates to:
  /// **'Expected Price'**
  String get expectedPrice;

  /// No description provided for @enterPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter expected price'**
  String get enterPrice;

  /// No description provided for @pricePerTon.
  ///
  /// In en, this message translates to:
  /// **'Price per tonne'**
  String get pricePerTon;

  /// No description provided for @negotiable.
  ///
  /// In en, this message translates to:
  /// **'Negotiable'**
  String get negotiable;

  /// No description provided for @fixedPrice.
  ///
  /// In en, this message translates to:
  /// **'Fixed Price'**
  String get fixedPrice;

  /// No description provided for @pickupDateHint.
  ///
  /// In en, this message translates to:
  /// **'When should pickup happen?'**
  String get pickupDateHint;

  /// No description provided for @pickupTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup Time'**
  String get pickupTime;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Load Expiry'**
  String get expiryDate;

  /// No description provided for @expiryHint.
  ///
  /// In en, this message translates to:
  /// **'Load will expire after 7 days by default'**
  String get expiryHint;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get additionalNotes;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Any special requirements?'**
  String get notesHint;

  /// No description provided for @postLoadButton.
  ///
  /// In en, this message translates to:
  /// **'Post Load'**
  String get postLoadButton;

  /// No description provided for @loadPostedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Load posted successfully!'**
  String get loadPostedSuccess;

  /// No description provided for @loadPostingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to post load. Please try again.'**
  String get loadPostingFailed;

  /// No description provided for @loadDetails.
  ///
  /// In en, this message translates to:
  /// **'Load Details'**
  String get loadDetails;

  /// No description provided for @postedOn.
  ///
  /// In en, this message translates to:
  /// **'Posted on {date}'**
  String postedOn(String date);

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String expiresOn(String date);

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @loadStatus.
  ///
  /// In en, this message translates to:
  /// **'Load Status'**
  String get loadStatus;

  /// No description provided for @interestedTruckers.
  ///
  /// In en, this message translates to:
  /// **'Interested Truckers'**
  String get interestedTruckers;

  /// No description provided for @noInterestsYet.
  ///
  /// In en, this message translates to:
  /// **'No interests yet'**
  String get noInterestsYet;

  /// No description provided for @viewInterests.
  ///
  /// In en, this message translates to:
  /// **'View Interests'**
  String get viewInterests;

  /// No description provided for @deactivateLoad.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Load'**
  String get deactivateLoad;

  /// No description provided for @deactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to deactivate this load?'**
  String get deactivateConfirm;

  /// No description provided for @loadDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Load deactivated successfully'**
  String get loadDeactivated;

  /// No description provided for @activateLoad.
  ///
  /// In en, this message translates to:
  /// **'Activate Load'**
  String get activateLoad;

  /// No description provided for @editLoad.
  ///
  /// In en, this message translates to:
  /// **'Edit Load'**
  String get editLoad;

  /// No description provided for @deleteLoad.
  ///
  /// In en, this message translates to:
  /// **'Delete Load'**
  String get deleteLoad;

  /// No description provided for @loadDeleted.
  ///
  /// In en, this message translates to:
  /// **'Load deleted successfully'**
  String get loadDeleted;

  /// No description provided for @confirmDeleteLoad.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this load?'**
  String get confirmDeleteLoad;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get thisActionCannotBeUndone;

  /// No description provided for @requestSuperLoad.
  ///
  /// In en, this message translates to:
  /// **'Request Super Load'**
  String get requestSuperLoad;

  /// No description provided for @superLoadDescription.
  ///
  /// In en, this message translates to:
  /// **'Admin will find the best trucker for you'**
  String get superLoadDescription;

  /// No description provided for @superLoadRequested.
  ///
  /// In en, this message translates to:
  /// **'Super Load requested!'**
  String get superLoadRequested;

  /// No description provided for @superLoadStatus.
  ///
  /// In en, this message translates to:
  /// **'Super Load Status'**
  String get superLoadStatus;

  /// No description provided for @assignedTrucker.
  ///
  /// In en, this message translates to:
  /// **'Assigned Trucker'**
  String get assignedTrucker;

  /// No description provided for @adminNotes.
  ///
  /// In en, this message translates to:
  /// **'Admin Notes'**
  String get adminNotes;

  /// No description provided for @superLoadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Super Load in progress'**
  String get superLoadInProgress;

  /// No description provided for @superLoadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Super Load completed'**
  String get superLoadCompleted;

  /// No description provided for @cancelSuperLoad.
  ///
  /// In en, this message translates to:
  /// **'Cancel Super Load Request'**
  String get cancelSuperLoad;

  /// No description provided for @findLoadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Loads'**
  String get findLoadsTitle;

  /// No description provided for @searchLoads.
  ///
  /// In en, this message translates to:
  /// **'Search loads...'**
  String get searchLoads;

  /// No description provided for @originFilter.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get originFilter;

  /// No description provided for @destinationFilter.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationFilter;

  /// No description provided for @truckTypeFilter.
  ///
  /// In en, this message translates to:
  /// **'Truck Type'**
  String get truckTypeFilter;

  /// No description provided for @verifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified Suppliers Only'**
  String get verifiedOnly;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get priceLowToHigh;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get priceHighToLow;

  /// No description provided for @nearestFirst.
  ///
  /// In en, this message translates to:
  /// **'Nearest First'**
  String get nearestFirst;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get newestFirst;

  /// No description provided for @noLoadsFound.
  ///
  /// In en, this message translates to:
  /// **'No loads found matching your criteria'**
  String get noLoadsFound;

  /// No description provided for @adjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get adjustFilters;

  /// No description provided for @loadsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} loads found'**
  String loadsFound(int count);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @showInterest.
  ///
  /// In en, this message translates to:
  /// **'Show Interest'**
  String get showInterest;

  /// No description provided for @interestSent.
  ///
  /// In en, this message translates to:
  /// **'Interest sent to supplier!'**
  String get interestSent;

  /// No description provided for @callSupplier.
  ///
  /// In en, this message translates to:
  /// **'Call Supplier'**
  String get callSupplier;

  /// No description provided for @loadInfo.
  ///
  /// In en, this message translates to:
  /// **'Load Information'**
  String get loadInfo;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @estimatedDistance.
  ///
  /// In en, this message translates to:
  /// **'Estimated Distance'**
  String get estimatedDistance;

  /// No description provided for @myFleetTitle.
  ///
  /// In en, this message translates to:
  /// **'My Fleet'**
  String get myFleetTitle;

  /// No description provided for @noTrucksYet.
  ///
  /// In en, this message translates to:
  /// **'No trucks added yet'**
  String get noTrucksYet;

  /// No description provided for @addYourFirstTruck.
  ///
  /// In en, this message translates to:
  /// **'Add your first truck to start finding loads'**
  String get addYourFirstTruck;

  /// No description provided for @truckNumber.
  ///
  /// In en, this message translates to:
  /// **'Truck Number'**
  String get truckNumber;

  /// No description provided for @bodyType.
  ///
  /// In en, this message translates to:
  /// **'Body Type'**
  String get bodyType;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity (Tonnes)'**
  String get capacity;

  /// No description provided for @truckStatus.
  ///
  /// In en, this message translates to:
  /// **'Truck Status'**
  String get truckStatus;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPending;

  /// No description provided for @verificationVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verificationVerified;

  /// No description provided for @uploadRcPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload RC Photo'**
  String get uploadRcPhoto;

  /// No description provided for @rcPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'RC photo is required for verification'**
  String get rcPhotoRequired;

  /// No description provided for @truckAdded.
  ///
  /// In en, this message translates to:
  /// **'Truck added! Pending admin verification.'**
  String get truckAdded;

  /// No description provided for @truckUpdated.
  ///
  /// In en, this message translates to:
  /// **'Truck updated successfully'**
  String get truckUpdated;

  /// No description provided for @truckDeleted.
  ///
  /// In en, this message translates to:
  /// **'Truck deleted successfully'**
  String get truckDeleted;

  /// No description provided for @viewTruck.
  ///
  /// In en, this message translates to:
  /// **'View Truck'**
  String get viewTruck;

  /// No description provided for @editTruck.
  ///
  /// In en, this message translates to:
  /// **'Edit Truck'**
  String get editTruck;

  /// No description provided for @deleteTruck.
  ///
  /// In en, this message translates to:
  /// **'Delete Truck'**
  String get deleteTruck;

  /// No description provided for @confirmDeleteTruck.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this truck?'**
  String get confirmDeleteTruck;

  /// No description provided for @openBody.
  ///
  /// In en, this message translates to:
  /// **'Open Body'**
  String get openBody;

  /// No description provided for @closedBody.
  ///
  /// In en, this message translates to:
  /// **'Closed Body'**
  String get closedBody;

  /// No description provided for @container.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get container;

  /// No description provided for @tanker.
  ///
  /// In en, this message translates to:
  /// **'Tanker'**
  String get tanker;

  /// No description provided for @trailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get trailer;

  /// No description provided for @flatbed.
  ///
  /// In en, this message translates to:
  /// **'Flatbed'**
  String get flatbed;

  /// No description provided for @halfBody.
  ///
  /// In en, this message translates to:
  /// **'Half Body'**
  String get halfBody;

  /// No description provided for @hydraulic.
  ///
  /// In en, this message translates to:
  /// **'Hydraulic'**
  String get hydraulic;

  /// No description provided for @myTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get myTripsTitle;

  /// No description provided for @activeTrips.
  ///
  /// In en, this message translates to:
  /// **'Active Trips'**
  String get activeTrips;

  /// No description provided for @tripHistory.
  ///
  /// In en, this message translates to:
  /// **'Trip History'**
  String get tripHistory;

  /// No description provided for @noActiveTrips.
  ///
  /// In en, this message translates to:
  /// **'No active trips'**
  String get noActiveTrips;

  /// No description provided for @noTripHistory.
  ///
  /// In en, this message translates to:
  /// **'No trip history yet'**
  String get noTripHistory;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get tripDetails;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get startTrip;

  /// No description provided for @endTrip.
  ///
  /// In en, this message translates to:
  /// **'End Trip'**
  String get endTrip;

  /// No description provided for @uploadPod.
  ///
  /// In en, this message translates to:
  /// **'Upload POD'**
  String get uploadPod;

  /// No description provided for @podUploaded.
  ///
  /// In en, this message translates to:
  /// **'POD uploaded successfully'**
  String get podUploaded;

  /// No description provided for @rateSupplier.
  ///
  /// In en, this message translates to:
  /// **'Rate Supplier'**
  String get rateSupplier;

  /// No description provided for @tripStarted.
  ///
  /// In en, this message translates to:
  /// **'Trip started'**
  String get tripStarted;

  /// No description provided for @tripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get tripCompleted;

  /// No description provided for @lrNumber.
  ///
  /// In en, this message translates to:
  /// **'LR Number'**
  String get lrNumber;

  /// No description provided for @enterLrNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter LR number'**
  String get enterLrNumber;

  /// No description provided for @conversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversations;

  /// No description provided for @noConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversations;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation by showing interest in a load'**
  String get startChat;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get typing;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String lastSeen(String time);

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get voiceMessage;

  /// No description provided for @holdToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get holdToRecord;

  /// No description provided for @releaseToSend.
  ///
  /// In en, this message translates to:
  /// **'Release to send'**
  String get releaseToSend;

  /// No description provided for @slideToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get slideToCancel;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @recordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording too short'**
  String get recordingTooShort;

  /// No description provided for @recordingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Recording cancelled'**
  String get recordingCancelled;

  /// No description provided for @messageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get messageSent;

  /// No description provided for @failedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get failedToSend;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get deleteMessage;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get deleteConfirm;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get messageDeleted;

  /// No description provided for @shareTruckCard.
  ///
  /// In en, this message translates to:
  /// **'Share Truck Card'**
  String get shareTruckCard;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location'**
  String get shareLocation;

  /// No description provided for @shareDocument.
  ///
  /// In en, this message translates to:
  /// **'Share Document'**
  String get shareDocument;

  /// No description provided for @locationShared.
  ///
  /// In en, this message translates to:
  /// **'Location shared'**
  String get locationShared;

  /// No description provided for @documentShared.
  ///
  /// In en, this message translates to:
  /// **'Document shared'**
  String get documentShared;

  /// No description provided for @truckCardShared.
  ///
  /// In en, this message translates to:
  /// **'Truck card shared'**
  String get truckCardShared;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get now;

  /// No description provided for @verificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Verification'**
  String get verificationTitle;

  /// No description provided for @verificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your account to unlock all features'**
  String get verificationSubtitle;

  /// No description provided for @businessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business Details'**
  String get businessDetails;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @enterBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Enter your business name'**
  String get enterBusinessName;

  /// No description provided for @gstNumber.
  ///
  /// In en, this message translates to:
  /// **'GST Number'**
  String get gstNumber;

  /// No description provided for @enterGst.
  ///
  /// In en, this message translates to:
  /// **'Enter 15-digit GST number'**
  String get enterGst;

  /// No description provided for @businessLicense.
  ///
  /// In en, this message translates to:
  /// **'Business License'**
  String get businessLicense;

  /// No description provided for @uploadLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload business license'**
  String get uploadLicense;

  /// No description provided for @kycDocuments.
  ///
  /// In en, this message translates to:
  /// **'KYC Documents'**
  String get kycDocuments;

  /// No description provided for @panNumber.
  ///
  /// In en, this message translates to:
  /// **'PAN Number'**
  String get panNumber;

  /// No description provided for @enterPan.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-character PAN'**
  String get enterPan;

  /// No description provided for @uploadPan.
  ///
  /// In en, this message translates to:
  /// **'Upload PAN card'**
  String get uploadPan;

  /// No description provided for @dlNumber.
  ///
  /// In en, this message translates to:
  /// **'Driving License Number'**
  String get dlNumber;

  /// No description provided for @enterDl.
  ///
  /// In en, this message translates to:
  /// **'Enter DL number'**
  String get enterDl;

  /// No description provided for @uploadDl.
  ///
  /// In en, this message translates to:
  /// **'Upload DL photo'**
  String get uploadDl;

  /// No description provided for @submitForVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submitForVerification;

  /// No description provided for @verificationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Verification submitted!'**
  String get verificationSubmitted;

  /// No description provided for @verificationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Verification in progress'**
  String get verificationInProgress;

  /// No description provided for @verificationApproved.
  ///
  /// In en, this message translates to:
  /// **'Verification approved!'**
  String get verificationApproved;

  /// No description provided for @verificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Verification rejected'**
  String get verificationRejected;

  /// No description provided for @rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String rejectionReason(String reason);

  /// No description provided for @resubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit'**
  String get resubmit;

  /// No description provided for @pendingVerification.
  ///
  /// In en, this message translates to:
  /// **'Pending Verification'**
  String get pendingVerification;

  /// No description provided for @getVerified.
  ///
  /// In en, this message translates to:
  /// **'Get Verified'**
  String get getVerified;

  /// No description provided for @benefitsOfVerification.
  ///
  /// In en, this message translates to:
  /// **'Benefits of Verification'**
  String get benefitsOfVerification;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified Badge'**
  String get verifiedBadge;

  /// No description provided for @prioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Support'**
  String get prioritySupport;

  /// No description provided for @unlimitedLoads.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Load Posting'**
  String get unlimitedLoads;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @smsNotifications.
  ///
  /// In en, this message translates to:
  /// **'SMS Notifications'**
  String get smsNotifications;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get dataExport;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirm;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChanged;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faq;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get invalidEmail;

  /// No description provided for @invalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 10-digit mobile number'**
  String get invalidMobile;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get invalidPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @invalidWeight.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid weight'**
  String get invalidWeight;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get invalidPrice;

  /// No description provided for @cityNotFound.
  ///
  /// In en, this message translates to:
  /// **'City not found in database'**
  String get cityNotFound;

  /// No description provided for @selectMaterialFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a material first'**
  String get selectMaterialFirst;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpired;

  /// No description provided for @unauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized access'**
  String get unauthorized;

  /// No description provided for @forbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this'**
  String get forbidden;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknownError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get tryAgain;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String fieldRequired(String field);

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get invalidInput;

  /// No description provided for @maxLengthExceeded.
  ///
  /// In en, this message translates to:
  /// **'Maximum length exceeded'**
  String get maxLengthExceeded;

  /// No description provided for @minLengthRequired.
  ///
  /// In en, this message translates to:
  /// **'Minimum length required'**
  String get minLengthRequired;

  /// No description provided for @botTitle.
  ///
  /// In en, this message translates to:
  /// **'TranZfort Assistant'**
  String get botTitle;

  /// No description provided for @botGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m your TranZfort assistant. How can I help?'**
  String get botGreeting;

  /// No description provided for @botTyping.
  ///
  /// In en, this message translates to:
  /// **'Assistant is typing...'**
  String get botTyping;

  /// No description provided for @botHelpOptions.
  ///
  /// In en, this message translates to:
  /// **'I can help you:\n• Post a new load\n• Find loads\n• Answer questions'**
  String get botHelpOptions;

  /// No description provided for @botDidntUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I didn\'t understand. Could you rephrase?'**
  String get botDidntUnderstand;

  /// No description provided for @botAskOrigin.
  ///
  /// In en, this message translates to:
  /// **'Where are you shipping from? (Origin city)'**
  String get botAskOrigin;

  /// No description provided for @botAskDestination.
  ///
  /// In en, this message translates to:
  /// **'Where are you shipping to? (Destination city)'**
  String get botAskDestination;

  /// No description provided for @botAskMaterial.
  ///
  /// In en, this message translates to:
  /// **'What material are you shipping?'**
  String get botAskMaterial;

  /// No description provided for @botAskWeight.
  ///
  /// In en, this message translates to:
  /// **'What\'s the weight? (in tonnes)'**
  String get botAskWeight;

  /// No description provided for @botAskTruckType.
  ///
  /// In en, this message translates to:
  /// **'What type of truck do you need?'**
  String get botAskTruckType;

  /// No description provided for @botConfirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Please confirm:\n📍 {origin} → {destination}\n📦 {material}\n⚖️ {weight} tonnes\n\nIs this correct?'**
  String botConfirmDetails(
    String origin,
    String destination,
    String material,
    String weight,
  );

  /// No description provided for @botLoadPosted.
  ///
  /// In en, this message translates to:
  /// **'✅ Load posted successfully!\nLoad ID: {loadId}'**
  String botLoadPosted(String loadId);

  /// No description provided for @botSearchingLoads.
  ///
  /// In en, this message translates to:
  /// **'🔍 Searching for loads...'**
  String get botSearchingLoads;

  /// No description provided for @botFoundLoads.
  ///
  /// In en, this message translates to:
  /// **'Found {count} loads matching your criteria:'**
  String botFoundLoads(int count);

  /// No description provided for @botNoLoadsFound.
  ///
  /// In en, this message translates to:
  /// **'No loads found. Try different cities or truck type.'**
  String get botNoLoadsFound;

  /// No description provided for @botThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using TranZfort! 👍'**
  String get botThanks;

  /// No description provided for @botDownloadAi.
  ///
  /// In en, this message translates to:
  /// **'Download AI'**
  String get botDownloadAi;

  /// No description provided for @botDownloadAiDescription.
  ///
  /// In en, this message translates to:
  /// **'Get smarter responses and better Hindi understanding'**
  String get botDownloadAiDescription;

  /// No description provided for @botAiModelSize.
  ///
  /// In en, this message translates to:
  /// **'{size} • One-time download'**
  String botAiModelSize(String size);

  /// No description provided for @botUseBasic.
  ///
  /// In en, this message translates to:
  /// **'Use Basic Assistant'**
  String get botUseBasic;

  /// No description provided for @botDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String botDownloadProgress(int percent);

  /// No description provided for @botDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete! Switching to AI mode...'**
  String get botDownloadComplete;

  /// No description provided for @botDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get botDownloadFailed;

  /// No description provided for @botWifiRequired.
  ///
  /// In en, this message translates to:
  /// **'WiFi required for download'**
  String get botWifiRequired;

  /// No description provided for @botStorageRequired.
  ///
  /// In en, this message translates to:
  /// **'{size} free space required'**
  String botStorageRequired(String size);

  /// No description provided for @botThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get botThinking;

  /// No description provided for @botResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get botResponse;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @quickReplies.
  ///
  /// In en, this message translates to:
  /// **'Quick Replies'**
  String get quickReplies;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @steel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get steel;

  /// No description provided for @cement.
  ///
  /// In en, this message translates to:
  /// **'Cement'**
  String get cement;

  /// No description provided for @sand.
  ///
  /// In en, this message translates to:
  /// **'Sand'**
  String get sand;

  /// No description provided for @bricks.
  ///
  /// In en, this message translates to:
  /// **'Bricks'**
  String get bricks;

  /// No description provided for @tiles.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get tiles;

  /// No description provided for @grain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get grain;

  /// No description provided for @wheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get wheat;

  /// No description provided for @rice.
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get rice;

  /// No description provided for @pulses.
  ///
  /// In en, this message translates to:
  /// **'Pulses'**
  String get pulses;

  /// No description provided for @sugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get sugar;

  /// No description provided for @electronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get electronics;

  /// No description provided for @furniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get furniture;

  /// No description provided for @textiles.
  ///
  /// In en, this message translates to:
  /// **'Textiles'**
  String get textiles;

  /// No description provided for @clothes.
  ///
  /// In en, this message translates to:
  /// **'Clothes'**
  String get clothes;

  /// No description provided for @machinery.
  ///
  /// In en, this message translates to:
  /// **'Machinery'**
  String get machinery;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @containers.
  ///
  /// In en, this message translates to:
  /// **'Containers'**
  String get containers;

  /// No description provided for @oil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get oil;

  /// No description provided for @chemicals.
  ///
  /// In en, this message translates to:
  /// **'Chemicals'**
  String get chemicals;

  /// No description provided for @fertilizers.
  ///
  /// In en, this message translates to:
  /// **'Fertilizers'**
  String get fertilizers;

  /// No description provided for @coal.
  ///
  /// In en, this message translates to:
  /// **'Coal'**
  String get coal;

  /// No description provided for @wood.
  ///
  /// In en, this message translates to:
  /// **'Wood'**
  String get wood;

  /// No description provided for @plastic.
  ///
  /// In en, this message translates to:
  /// **'Plastic'**
  String get plastic;

  /// No description provided for @glass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get glass;

  /// No description provided for @paper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paper;

  /// No description provided for @scrap.
  ///
  /// In en, this message translates to:
  /// **'Scrap'**
  String get scrap;

  /// No description provided for @mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed Goods'**
  String get mixed;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
