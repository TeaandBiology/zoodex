import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cy.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('cy'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZooDex'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @homeShellZoos.
  ///
  /// In en, this message translates to:
  /// **'Zoos'**
  String get homeShellZoos;

  /// No description provided for @homeShellSpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get homeShellSpecies;

  /// No description provided for @homeShellProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get homeShellProfile;

  /// No description provided for @zoodexTitle.
  ///
  /// In en, this message translates to:
  /// **'Species ({count})'**
  String zoodexTitle(int count);

  /// No description provided for @zoodexListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get zoodexListView;

  /// No description provided for @zoodexGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get zoodexGridView;

  /// No description provided for @zoodexTreeOfLife.
  ///
  /// In en, this message translates to:
  /// **'Tree of life'**
  String get zoodexTreeOfLife;

  /// No description provided for @zoodexFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get zoodexFilter;

  /// No description provided for @zoodexSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get zoodexSort;

  /// No description provided for @zoodexSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search species, zoo, group...'**
  String get zoodexSearchHint;

  /// No description provided for @zoodexClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get zoodexClear;

  /// No description provided for @zoodexNoSightingsYet.
  ///
  /// In en, this message translates to:
  /// **'No sightings yet.'**
  String get zoodexNoSightingsYet;

  /// No description provided for @zoodexNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches.'**
  String get zoodexNoMatches;

  /// No description provided for @zoodexClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get zoodexClearAll;

  /// No description provided for @zoodexGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get zoodexGroup;

  /// No description provided for @zoodexIucnStatus.
  ///
  /// In en, this message translates to:
  /// **'IUCN status'**
  String get zoodexIucnStatus;

  /// No description provided for @zoodexSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get zoodexSortBy;

  /// No description provided for @zoodexAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get zoodexAscending;

  /// No description provided for @zoodexDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get zoodexDescending;

  /// No description provided for @zoodexLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {date}'**
  String zoodexLastSeen(String date);

  /// No description provided for @treeViewNoSightingsYet.
  ///
  /// In en, this message translates to:
  /// **'No sightings yet.'**
  String get treeViewNoSightingsYet;

  /// No description provided for @treeViewTree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get treeViewTree;

  /// No description provided for @treeViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get treeViewList;

  /// No description provided for @treeViewAllLife.
  ///
  /// In en, this message translates to:
  /// **'All life'**
  String get treeViewAllLife;

  /// No description provided for @speciesDetailSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get speciesDetailSeen;

  /// No description provided for @speciesDetailNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get speciesDetailNoShow;

  /// No description provided for @speciesDetailAddPersonalNote.
  ///
  /// In en, this message translates to:
  /// **'Add a Personal Note'**
  String get speciesDetailAddPersonalNote;

  /// No description provided for @speciesDetailPersonalNote.
  ///
  /// In en, this message translates to:
  /// **'Personal Note'**
  String get speciesDetailPersonalNote;

  /// No description provided for @speciesDetailNotePrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Private - only you can see this'**
  String get speciesDetailNotePrivateHint;

  /// No description provided for @speciesDetailRemoveRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this record?'**
  String get speciesDetailRemoveRecordTitle;

  /// No description provided for @speciesDetailRecordSighting.
  ///
  /// In en, this message translates to:
  /// **'sighting'**
  String get speciesDetailRecordSighting;

  /// No description provided for @speciesDetailRecordNoShow.
  ///
  /// In en, this message translates to:
  /// **'no-show'**
  String get speciesDetailRecordNoShow;

  /// No description provided for @speciesDetailRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get speciesDetailRemove;

  /// No description provided for @speciesDetailRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get speciesDetailRemoved;

  /// No description provided for @speciesDetailUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get speciesDetailUndo;

  /// No description provided for @speciesDetailClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all records?'**
  String get speciesDetailClearAllTitle;

  /// No description provided for @speciesDetailClearAllBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every seen/no-show record for this species.'**
  String get speciesDetailClearAllBody;

  /// No description provided for @speciesDetailClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get speciesDetailClear;

  /// No description provided for @speciesDetailBreeds.
  ///
  /// In en, this message translates to:
  /// **'Breeds'**
  String get speciesDetailBreeds;

  /// No description provided for @speciesDetailSubspecies.
  ///
  /// In en, this message translates to:
  /// **'Subspecies'**
  String get speciesDetailSubspecies;

  /// No description provided for @speciesDetailViewFullImage.
  ///
  /// In en, this message translates to:
  /// **'View full image'**
  String get speciesDetailViewFullImage;

  /// No description provided for @speciesDetailClearAllRecords.
  ///
  /// In en, this message translates to:
  /// **'Clear all records'**
  String get speciesDetailClearAllRecords;

  /// No description provided for @speciesDetailReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get speciesDetailReportProblem;

  /// No description provided for @speciesDetailReportWrongPhoto.
  ///
  /// In en, this message translates to:
  /// **'Wrong or missing photo'**
  String get speciesDetailReportWrongPhoto;

  /// No description provided for @speciesDetailReportFactualError.
  ///
  /// In en, this message translates to:
  /// **'Factual error'**
  String get speciesDetailReportFactualError;

  /// No description provided for @speciesDetailReportWrongTaxonomy.
  ///
  /// In en, this message translates to:
  /// **'Wrong taxonomy / IUCN'**
  String get speciesDetailReportWrongTaxonomy;

  /// No description provided for @speciesDetailReportProblemMenu.
  ///
  /// In en, this message translates to:
  /// **'Report a problem...'**
  String get speciesDetailReportProblemMenu;

  /// No description provided for @speciesDetailNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet.'**
  String get speciesDetailNoDescription;

  /// No description provided for @speciesDetailSeenNow.
  ///
  /// In en, this message translates to:
  /// **'Seen Now'**
  String get speciesDetailSeenNow;

  /// No description provided for @speciesDetailEditPersonalNote.
  ///
  /// In en, this message translates to:
  /// **'Edit personal note'**
  String get speciesDetailEditPersonalNote;

  /// No description provided for @speciesDetailAddPersonalNoteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a personal note'**
  String get speciesDetailAddPersonalNoteTooltip;

  /// No description provided for @speciesDetailLogPastSighting.
  ///
  /// In en, this message translates to:
  /// **'Log a past sighting'**
  String get speciesDetailLogPastSighting;

  /// No description provided for @speciesDetailNoneSeenYet.
  ///
  /// In en, this message translates to:
  /// **'None seen yet'**
  String get speciesDetailNoneSeenYet;

  /// No description provided for @speciesDetailNotSeenYet.
  ///
  /// In en, this message translates to:
  /// **'Not seen yet'**
  String get speciesDetailNotSeenYet;

  /// No description provided for @speciesDetailNoSightingsYet.
  ///
  /// In en, this message translates to:
  /// **'No sightings yet'**
  String get speciesDetailNoSightingsYet;

  /// No description provided for @speciesDetailNoSightingsYetPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sightings yet.'**
  String get speciesDetailNoSightingsYetPeriod;

  /// No description provided for @speciesDetailAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get speciesDetailAbout;

  /// No description provided for @speciesDetailRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get speciesDetailRange;

  /// No description provided for @speciesDetailTapToEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Tap to enlarge'**
  String get speciesDetailTapToEnlarge;

  /// No description provided for @speciesDetailTaxonomy.
  ///
  /// In en, this message translates to:
  /// **'Taxonomy'**
  String get speciesDetailTaxonomy;

  /// No description provided for @speciesDetailNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get speciesDetailNotRecorded;

  /// No description provided for @speciesDetailNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get speciesDetailNotAvailable;

  /// No description provided for @speciesDetailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get speciesDetailVerified;

  /// No description provided for @speciesDetailEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get speciesDetailEditNote;

  /// No description provided for @speciesDetailAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get speciesDetailAddNote;

  /// No description provided for @speciesDetailRemoveThisRecord.
  ///
  /// In en, this message translates to:
  /// **'Remove this record'**
  String get speciesDetailRemoveThisRecord;

  /// No description provided for @speciesDetailSaved.
  ///
  /// In en, this message translates to:
  /// **'{what} saved'**
  String speciesDetailSaved(String what);

  /// No description provided for @speciesDetailSavedVerified.
  ///
  /// In en, this message translates to:
  /// **'{what} saved - verified'**
  String speciesDetailSavedVerified(String what);

  /// No description provided for @speciesDetailLoggedFor.
  ///
  /// In en, this message translates to:
  /// **'Logged for {date}'**
  String speciesDetailLoggedFor(String date);

  /// No description provided for @speciesDetailDeleteRecordBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the {what} from {date} at {zoo}?'**
  String speciesDetailDeleteRecordBody(String what, String date, String zoo);

  /// No description provided for @speciesDetailCollectedCount.
  ///
  /// In en, this message translates to:
  /// **'{seen} of {total} collected'**
  String speciesDetailCollectedCount(int seen, int total);

  /// No description provided for @speciesDetailSeenAcrossSubspecies.
  ///
  /// In en, this message translates to:
  /// **'Seen {count} time(s) across subspecies - Last: {date}'**
  String speciesDetailSeenAcrossSubspecies(int count, String date);

  /// No description provided for @speciesDetailSeenTimes.
  ///
  /// In en, this message translates to:
  /// **'Seen {count} time(s) - Last: {date}'**
  String speciesDetailSeenTimes(int count, String date);

  /// No description provided for @speciesDetailCopyrightInfo.
  ///
  /// In en, this message translates to:
  /// **'Copyright Information: {text}'**
  String speciesDetailCopyrightInfo(String text);

  /// No description provided for @speciesDetailSightingTitle.
  ///
  /// In en, this message translates to:
  /// **'{date} - {outcome}'**
  String speciesDetailSightingTitle(String date, String outcome);

  /// No description provided for @zooSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Zoos'**
  String get zooSelectTitle;

  /// No description provided for @zooSelectViewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get zooSelectViewMap;

  /// No description provided for @zooSelectViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get zooSelectViewList;

  /// No description provided for @zooSelectSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search zoos'**
  String get zooSelectSearchHint;

  /// No description provided for @zooSelectClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get zooSelectClear;

  /// No description provided for @zooSelectNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching zoos'**
  String get zooSelectNoMatches;

  /// No description provided for @zooSelectPlanUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited - all zoos unlocked'**
  String get zooSelectPlanUnlimited;

  /// No description provided for @zooSelectLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get zooSelectLocked;

  /// No description provided for @zooSelectPlanPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium - all {country} zoos unlocked'**
  String zooSelectPlanPremium(String country);

  /// No description provided for @zooSelectPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Free plan - {remaining} of {max} free unlocks remaining'**
  String zooSelectPlanFree(int remaining, int max);

  /// No description provided for @zooSelectSpeciesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} species'**
  String zooSelectSpeciesCount(int count);

  /// No description provided for @zooMapNoCoords.
  ///
  /// In en, this message translates to:
  /// **'No zoos have map coordinates yet.'**
  String get zooMapNoCoords;

  /// No description provided for @zooMapCentreOnMe.
  ///
  /// In en, this message translates to:
  /// **'Centre on my location'**
  String get zooMapCentreOnMe;

  /// No description provided for @zooInfoAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get zooInfoAbout;

  /// No description provided for @zooInfoOpeningTimes.
  ///
  /// In en, this message translates to:
  /// **'Opening times'**
  String get zooInfoOpeningTimes;

  /// No description provided for @zooInfoOpeningTimesSoon.
  ///
  /// In en, this message translates to:
  /// **'Opening times coming soon.'**
  String get zooInfoOpeningTimesSoon;

  /// No description provided for @zooInfoWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get zooInfoWebsite;

  /// No description provided for @zooInfoWebsiteNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added yet.'**
  String get zooInfoWebsiteNotAdded;

  /// No description provided for @zooInfoSocialMedia.
  ///
  /// In en, this message translates to:
  /// **'Social media'**
  String get zooInfoSocialMedia;

  /// No description provided for @zooInfoLinksSoon.
  ///
  /// In en, this message translates to:
  /// **'Links coming soon.'**
  String get zooInfoLinksSoon;

  /// No description provided for @zooInfoDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get zooInfoDetails;

  /// No description provided for @zooInfoCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get zooInfoCountry;

  /// No description provided for @zooInfoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Info updated'**
  String get zooInfoUpdated;

  /// No description provided for @zooInfoAboutPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'A short description of {name} will go here.'**
  String zooInfoAboutPlaceholder(String name);

  /// No description provided for @zooInventoryNoData.
  ///
  /// In en, this message translates to:
  /// **'No data.'**
  String get zooInventoryNoData;

  /// No description provided for @zooInventoryZooInfo.
  ///
  /// In en, this message translates to:
  /// **'Zoo info'**
  String get zooInventoryZooInfo;

  /// No description provided for @zooInventoryMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get zooInventoryMore;

  /// No description provided for @zooInventoryReportMissing.
  ///
  /// In en, this message translates to:
  /// **'Report a missing species'**
  String get zooInventoryReportMissing;

  /// No description provided for @zooInventoryReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get zooInventoryReportProblem;

  /// No description provided for @zooInventorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search species, group, zone...'**
  String get zooInventorySearchHint;

  /// No description provided for @zooInventoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get zooInventoryGroup;

  /// No description provided for @zooInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} ({seen}/{total})'**
  String zooInventoryTitle(String name, int seen, int total);

  /// No description provided for @profileNoDataToExport.
  ///
  /// In en, this message translates to:
  /// **'No data to export yet.'**
  String get profileNoDataToExport;

  /// No description provided for @profileSharingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing unavailable here - data copied to clipboard.'**
  String get profileSharingUnavailable;

  /// No description provided for @profileSetHomeCountry.
  ///
  /// In en, this message translates to:
  /// **'Set home country'**
  String get profileSetHomeCountry;

  /// No description provided for @profileSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get profileSet;

  /// No description provided for @profileAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get profileAddFriend;

  /// No description provided for @profileEnterFriendCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend code to send a request.'**
  String get profileEnterFriendCode;

  /// No description provided for @profileFriendCode.
  ///
  /// In en, this message translates to:
  /// **'Friend code'**
  String get profileFriendCode;

  /// No description provided for @profileFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profileFriends;

  /// No description provided for @profileAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get profileAdd;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileProfileEditing.
  ///
  /// In en, this message translates to:
  /// **'Profile editing'**
  String get profileProfileEditing;

  /// No description provided for @profileSetCountry.
  ///
  /// In en, this message translates to:
  /// **'Set country'**
  String get profileSetCountry;

  /// No description provided for @profileAddFriends.
  ///
  /// In en, this message translates to:
  /// **'Add friends'**
  String get profileAddFriends;

  /// No description provided for @profileExportData.
  ///
  /// In en, this message translates to:
  /// **'Export data (CSV)'**
  String get profileExportData;

  /// No description provided for @profileOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get profileOverview;

  /// No description provided for @profileAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get profileAchievements;

  /// No description provided for @profileClearLocalZoo.
  ///
  /// In en, this message translates to:
  /// **'Clear local zoo'**
  String get profileClearLocalZoo;

  /// No description provided for @profileVisitToSetLocalZoo.
  ///
  /// In en, this message translates to:
  /// **'Visit a zoo to set your local zoo'**
  String get profileVisitToSetLocalZoo;

  /// No description provided for @profileLocalZooNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set - tap to choose'**
  String get profileLocalZooNotSet;

  /// No description provided for @profileLocalZoo.
  ///
  /// In en, this message translates to:
  /// **'Local zoo'**
  String get profileLocalZoo;

  /// No description provided for @profileSpeciesSeen.
  ///
  /// In en, this message translates to:
  /// **'Species seen'**
  String get profileSpeciesSeen;

  /// No description provided for @profileZoosVisited.
  ///
  /// In en, this message translates to:
  /// **'Zoos visited'**
  String get profileZoosVisited;

  /// No description provided for @profileSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get profileSightings;

  /// No description provided for @profileAchievementsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Earn awards for milestones like species seen and zoos visited. Only verified sightings will count. Coming soon.'**
  String get profileAchievementsPlaceholder;

  /// No description provided for @profileComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{what} is coming soon'**
  String profileComingSoon(String what);

  /// No description provided for @profileJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String profileJoined(String date);

  /// No description provided for @paywallNoFreeUnlocksLeft.
  ///
  /// In en, this message translates to:
  /// **'No free unlocks left'**
  String get paywallNoFreeUnlocksLeft;

  /// No description provided for @paywallPurchaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Purchase complete'**
  String get paywallPurchaseComplete;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallRestoreRequested.
  ///
  /// In en, this message translates to:
  /// **'Restore requested'**
  String get paywallRestoreRequested;

  /// No description provided for @paywallDevelopmentMode.
  ///
  /// In en, this message translates to:
  /// **'Development mode: purchases are simulated and not validated.'**
  String get paywallDevelopmentMode;

  /// No description provided for @paywallPremiumHomeCountry.
  ///
  /// In en, this message translates to:
  /// **'Premium (home country)'**
  String get paywallPremiumHomeCountry;

  /// No description provided for @paywallSetHomeCountryToEnable.
  ///
  /// In en, this message translates to:
  /// **'Set your home country in Settings to enable.'**
  String get paywallSetHomeCountryToEnable;

  /// No description provided for @paywallUnlimitedWorldwide.
  ///
  /// In en, this message translates to:
  /// **'Unlimited - every zoo, worldwide'**
  String get paywallUnlimitedWorldwide;

  /// No description provided for @paywallUnlimitedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, all zoos everywhere.'**
  String get paywallUnlimitedSubtitle;

  /// No description provided for @paywallRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestorePurchases;

  /// No description provided for @paywallZooUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{zooName} unlocked'**
  String paywallZooUnlocked(String zooName);

  /// No description provided for @paywallUnlockZoo.
  ///
  /// In en, this message translates to:
  /// **'Unlock {zooName}'**
  String paywallUnlockZoo(String zooName);

  /// No description provided for @paywallFirstZoosFree.
  ///
  /// In en, this message translates to:
  /// **'The first {count} zoos are free.'**
  String paywallFirstZoosFree(int count);

  /// No description provided for @paywallUseFreeUnlock.
  ///
  /// In en, this message translates to:
  /// **'Use a free unlock ({count} left)'**
  String paywallUseFreeUnlock(int count);

  /// No description provided for @paywallPremiumAllZoos.
  ///
  /// In en, this message translates to:
  /// **'Premium - all {country} zoos'**
  String paywallPremiumAllZoos(String country);

  /// No description provided for @paywallUnlocksEveryZooIn.
  ///
  /// In en, this message translates to:
  /// **'Unlocks every zoo in {country}.'**
  String paywallUnlocksEveryZooIn(String country);

  /// No description provided for @paywallCoversZoosChooseUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Covers {country} zoos - this zoo is in {zooCountry}. Choose Unlimited.'**
  String paywallCoversZoosChooseUnlimited(String country, String zooCountry);

  /// No description provided for @errorViewSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorViewSomethingWentWrong;

  /// No description provided for @errorViewUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get errorViewUnknownError;

  /// No description provided for @reportSheetReportAProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportSheetReportAProblem;

  /// No description provided for @reportSheetThanksReportSaved.
  ///
  /// In en, this message translates to:
  /// **'Thanks - report saved'**
  String get reportSheetThanksReportSaved;

  /// No description provided for @reportSheetSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get reportSheetSend;

  /// No description provided for @reportSheetShareSubject.
  ///
  /// In en, this message translates to:
  /// **'ZooDex problem report'**
  String get reportSheetShareSubject;

  /// No description provided for @reportSheetCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied report to clipboard'**
  String get reportSheetCopiedToClipboard;

  /// No description provided for @reportSheetWhatsWrong.
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong?'**
  String get reportSheetWhatsWrong;

  /// No description provided for @reportSheetWhichSpecies.
  ///
  /// In en, this message translates to:
  /// **'Which species, and any details?'**
  String get reportSheetWhichSpecies;

  /// No description provided for @reportSheetNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get reportSheetNotesOptional;

  /// No description provided for @reportSheetMissingHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Asian small-clawed otter, in the wetlands house\"'**
  String get reportSheetMissingHint;

  /// No description provided for @reportSheetDescribeProblem.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get reportSheetDescribeProblem;

  /// No description provided for @reportSheetSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get reportSheetSaving;

  /// No description provided for @reportSheetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reportSheetSubmit;

  /// No description provided for @rangeMapCaption.
  ///
  /// In en, this message translates to:
  /// **'{species} - range'**
  String rangeMapCaption(String species);

  /// No description provided for @settingsNightMode.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get settingsNightMode;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsHomeCountry.
  ///
  /// In en, this message translates to:
  /// **'Home country'**
  String get settingsHomeCountry;

  /// No description provided for @settingsSetHomeCountry.
  ///
  /// In en, this message translates to:
  /// **'Set home country'**
  String get settingsSetHomeCountry;

  /// No description provided for @settingsSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get settingsSet;

  /// No description provided for @settingsPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get settingsPlan;

  /// No description provided for @settingsPlanUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited - every zoo'**
  String get settingsPlanUnlimited;

  /// No description provided for @settingsRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestorePurchases;

  /// No description provided for @settingsRestoreRequested.
  ///
  /// In en, this message translates to:
  /// **'Restore requested'**
  String get settingsRestoreRequested;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get settingsReportProblem;

  /// No description provided for @settingsReportProblemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong image, factual error, missing species...'**
  String get settingsReportProblemSubtitle;

  /// No description provided for @settingsDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloper;

  /// No description provided for @settingsResetEntitlements.
  ///
  /// In en, this message translates to:
  /// **'Reset entitlements (dev)'**
  String get settingsResetEntitlements;

  /// No description provided for @settingsResetEntitlementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clears plan and free unlocks'**
  String get settingsResetEntitlementsSubtitle;

  /// No description provided for @settingsEntitlementsReset.
  ///
  /// In en, this message translates to:
  /// **'Entitlements reset'**
  String get settingsEntitlementsReset;

  /// No description provided for @settingsResetOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Reset onboarding (dev)'**
  String get settingsResetOnboarding;

  /// No description provided for @settingsResetOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-shows the first-run flow; also clears home country + free unlocks so the flow takes effect again (keeps your user id)'**
  String get settingsResetOnboardingSubtitle;

  /// No description provided for @settingsAddAllSpecies.
  ///
  /// In en, this message translates to:
  /// **'Add all species (dev)'**
  String get settingsAddAllSpecies;

  /// No description provided for @settingsAddAllSpeciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Marks every catalogue species seen so the Species tab is fully populated'**
  String get settingsAddAllSpeciesSubtitle;

  /// No description provided for @settingsRemoveDevSpecies.
  ///
  /// In en, this message translates to:
  /// **'Remove dev species'**
  String get settingsRemoveDevSpecies;

  /// No description provided for @settingsRemoveDevSpeciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes only the \"add all species\" sightings'**
  String get settingsRemoveDevSpeciesSubtitle;

  /// No description provided for @settingsDevSpeciesRemoved.
  ///
  /// In en, this message translates to:
  /// **'Dev species removed'**
  String get settingsDevSpeciesRemoved;

  /// No description provided for @settingsCheckCatalogueData.
  ///
  /// In en, this message translates to:
  /// **'Check catalogue data'**
  String get settingsCheckCatalogueData;

  /// No description provided for @settingsNoProblemsFound.
  ///
  /// In en, this message translates to:
  /// **'No problems found'**
  String get settingsNoProblemsFound;

  /// No description provided for @settingsCatalogueData.
  ///
  /// In en, this message translates to:
  /// **'Catalogue data'**
  String get settingsCatalogueData;

  /// No description provided for @settingsCatalogueDataNoProblems.
  ///
  /// In en, this message translates to:
  /// **'No problems found. Every subspecies/breed points at a species that exists in the catalogue.'**
  String get settingsCatalogueDataNoProblems;

  /// No description provided for @settingsExportReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share all collected problem reports'**
  String get settingsExportReportsSubtitle;

  /// No description provided for @settingsReportsShareSubject.
  ///
  /// In en, this message translates to:
  /// **'ZooDex problem reports'**
  String get settingsReportsShareSubject;

  /// No description provided for @settingsCopiedReports.
  ///
  /// In en, this message translates to:
  /// **'Copied reports to clipboard'**
  String get settingsCopiedReports;

  /// No description provided for @settingsClearReports.
  ///
  /// In en, this message translates to:
  /// **'Clear reports'**
  String get settingsClearReports;

  /// No description provided for @settingsReportsCleared.
  ///
  /// In en, this message translates to:
  /// **'Reports cleared'**
  String get settingsReportsCleared;

  /// No description provided for @settingsHomeCountrySetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{country} (set once - premium applies here)'**
  String settingsHomeCountrySetSubtitle(String country);

  /// No description provided for @settingsPlanPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium - all {country} zoos'**
  String settingsPlanPremium(String country);

  /// No description provided for @settingsPlanFree.
  ///
  /// In en, this message translates to:
  /// **'Free - {used}/{max} unlocks used'**
  String settingsPlanFree(int used, int max);

  /// No description provided for @settingsAddedSpecies.
  ///
  /// In en, this message translates to:
  /// **'Added {count} species to the Dex'**
  String settingsAddedSpecies(int count);

  /// No description provided for @settingsProblemsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} problem(s) found - tap for details'**
  String settingsProblemsFound(int count);

  /// No description provided for @settingsExportReports.
  ///
  /// In en, this message translates to:
  /// **'Export reports ({count})'**
  String settingsExportReports(int count);

  /// No description provided for @onboardingCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you based?'**
  String get onboardingCountryTitle;

  /// No description provided for @onboardingCountrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your home country. A Premium unlock covers every zoo here. This is set once and can\'t be changed later.'**
  String get onboardingCountrySubtitle;

  /// No description provided for @onboardingNoCountries.
  ///
  /// In en, this message translates to:
  /// **'No zoo countries available yet.'**
  String get onboardingNoCountries;

  /// No description provided for @onboardingHomeCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Home country'**
  String get onboardingHomeCountryLabel;

  /// No description provided for @onboardingLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get onboardingLanguageLabel;

  /// No description provided for @onboardingStartExploring.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get onboardingStartExploring;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to ZooDex'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track the animals you spot at the zoos you visit - your own living Pokedex of real wildlife. Let\'s set you up.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onboardingNameTitle;

  /// No description provided for @onboardingNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your display name - shown on your profile. You can change it later.'**
  String get onboardingNameSubtitle;

  /// No description provided for @onboardingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingNameLabel;

  /// No description provided for @onboardingUsernameTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a handle'**
  String get onboardingUsernameTitle;

  /// No description provided for @onboardingUsernameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your @username. It\'s saved for now and becomes your unique handle when accounts go live - so it may need tweaking if it\'s taken.'**
  String get onboardingUsernameSubtitle;

  /// No description provided for @onboardingUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get onboardingUsernameLabel;

  /// No description provided for @onboardingUsernameHelper.
  ///
  /// In en, this message translates to:
  /// **'Lowercase letters, numbers and underscores.'**
  String get onboardingUsernameHelper;

  /// No description provided for @onboardingAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar'**
  String get onboardingAvatarTitle;

  /// No description provided for @onboardingAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Picks a look for your profile.'**
  String get onboardingAvatarSubtitle;

  /// No description provided for @onboardingZooTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your first zoo'**
  String get onboardingZooTitle;

  /// No description provided for @onboardingZooSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your first three zoos are free - choose one to start (or skip and pick later).'**
  String get onboardingZooSubtitle;
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
      <String>['cy', 'de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cy':
      return AppLocalizationsCy();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
