// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ZooDex';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonShare => 'Share';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAll => 'All';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSkip => 'Skip';

  @override
  String get homeShellZoos => 'Zoos';

  @override
  String get homeShellSpecies => 'Species';

  @override
  String get homeShellProfile => 'Profile';

  @override
  String zoodexTitle(int count) {
    return 'Species ($count)';
  }

  @override
  String get zoodexListView => 'List view';

  @override
  String get zoodexGridView => 'Grid view';

  @override
  String get zoodexTreeOfLife => 'Tree of life';

  @override
  String get zoodexFilter => 'Filter';

  @override
  String get zoodexSort => 'Sort';

  @override
  String get zoodexSearchHint => 'Search species, zoo, group...';

  @override
  String get zoodexClear => 'Clear';

  @override
  String get zoodexNoSightingsYet => 'No sightings yet.';

  @override
  String get zoodexNoMatches => 'No matches.';

  @override
  String get zoodexClearAll => 'Clear all';

  @override
  String get zoodexGroup => 'Group';

  @override
  String get zoodexIucnStatus => 'IUCN status';

  @override
  String get zoodexSortBy => 'Sort by';

  @override
  String get zoodexAscending => 'Ascending';

  @override
  String get zoodexDescending => 'Descending';

  @override
  String zoodexLastSeen(String date) {
    return 'Last seen: $date';
  }

  @override
  String get treeViewNoSightingsYet => 'No sightings yet.';

  @override
  String get treeViewTree => 'Tree';

  @override
  String get treeViewList => 'List';

  @override
  String get treeViewAllLife => 'All life';

  @override
  String get speciesDetailSeen => 'Seen';

  @override
  String get speciesDetailNoShow => 'No-show';

  @override
  String get speciesDetailAddPersonalNote => 'Add a Personal Note';

  @override
  String get speciesDetailPersonalNote => 'Personal Note';

  @override
  String get speciesDetailNotePrivateHint => 'Private - only you can see this';

  @override
  String get speciesDetailRemoveRecordTitle => 'Remove this record?';

  @override
  String get speciesDetailRecordSighting => 'sighting';

  @override
  String get speciesDetailRecordNoShow => 'no-show';

  @override
  String get speciesDetailRemove => 'Remove';

  @override
  String get speciesDetailRemoved => 'Removed';

  @override
  String get speciesDetailUndo => 'Undo';

  @override
  String get speciesDetailClearAllTitle => 'Clear all records?';

  @override
  String get speciesDetailClearAllBody =>
      'This removes every seen/no-show record for this species.';

  @override
  String get speciesDetailClear => 'Clear';

  @override
  String get speciesDetailBreeds => 'Breeds';

  @override
  String get speciesDetailSubspecies => 'Subspecies';

  @override
  String get speciesDetailViewFullImage => 'View full image';

  @override
  String get speciesDetailClearAllRecords => 'Clear all records';

  @override
  String get speciesDetailReportProblem => 'Report a problem';

  @override
  String get speciesDetailReportWrongPhoto => 'Wrong or missing photo';

  @override
  String get speciesDetailReportFactualError => 'Factual error';

  @override
  String get speciesDetailReportWrongTaxonomy => 'Wrong taxonomy / IUCN';

  @override
  String get speciesDetailReportProblemMenu => 'Report a problem...';

  @override
  String get speciesDetailNoDescription => 'No description yet.';

  @override
  String get speciesDetailSeenNow => 'Seen Now';

  @override
  String get speciesDetailEditPersonalNote => 'Edit personal note';

  @override
  String get speciesDetailAddPersonalNoteTooltip => 'Add a personal note';

  @override
  String get speciesDetailLogPastSighting => 'Log a past sighting';

  @override
  String get speciesDetailNoneSeenYet => 'None seen yet';

  @override
  String get speciesDetailNotSeenYet => 'Not seen yet';

  @override
  String get speciesDetailNoSightingsYet => 'No sightings yet';

  @override
  String get speciesDetailNoSightingsYetPeriod => 'No sightings yet.';

  @override
  String get speciesDetailAbout => 'About';

  @override
  String get speciesDetailRange => 'Range';

  @override
  String get speciesDetailTapToEnlarge => 'Tap to enlarge';

  @override
  String get speciesDetailTaxonomy => 'Taxonomy';

  @override
  String get speciesDetailNotRecorded => 'Not recorded';

  @override
  String get speciesDetailNotAvailable => 'Not available';

  @override
  String get speciesDetailVerified => 'Verified';

  @override
  String get speciesDetailEditNote => 'Edit note';

  @override
  String get speciesDetailAddNote => 'Add a note';

  @override
  String get speciesDetailRemoveThisRecord => 'Remove this record';

  @override
  String speciesDetailSaved(String what) {
    return '$what saved';
  }

  @override
  String speciesDetailSavedVerified(String what) {
    return '$what saved - verified';
  }

  @override
  String speciesDetailLoggedFor(String date) {
    return 'Logged for $date';
  }

  @override
  String speciesDetailDeleteRecordBody(String what, String date, String zoo) {
    return 'Delete the $what from $date at $zoo?';
  }

  @override
  String speciesDetailCollectedCount(int seen, int total) {
    return '$seen of $total collected';
  }

  @override
  String speciesDetailSeenAcrossSubspecies(int count, String date) {
    return 'Seen $count time(s) across subspecies - Last: $date';
  }

  @override
  String speciesDetailSeenTimes(int count, String date) {
    return 'Seen $count time(s) - Last: $date';
  }

  @override
  String speciesDetailCopyrightInfo(String text) {
    return 'Copyright Information: $text';
  }

  @override
  String speciesDetailSightingTitle(String date, String outcome) {
    return '$date - $outcome';
  }

  @override
  String get zooSelectTitle => 'Zoos';

  @override
  String get zooSelectViewMap => 'Map';

  @override
  String get zooSelectViewList => 'List';

  @override
  String get zooSelectSearchHint => 'Search zoos';

  @override
  String get zooSelectClear => 'Clear';

  @override
  String get zooSelectNoMatches => 'No matching zoos';

  @override
  String get zooSelectPlanUnlimited => 'Unlimited - all zoos unlocked';

  @override
  String get zooSelectLocked => 'Locked';

  @override
  String zooSelectPlanPremium(String country) {
    return 'Premium - all $country zoos unlocked';
  }

  @override
  String zooSelectPlanFree(int remaining, int max) {
    return 'Free plan - $remaining of $max free unlocks remaining';
  }

  @override
  String zooSelectSpeciesCount(int count) {
    return '$count species';
  }

  @override
  String get zooMapNoCoords => 'No zoos have map coordinates yet.';

  @override
  String get zooMapCentreOnMe => 'Centre on my location';

  @override
  String get zooInfoAbout => 'About';

  @override
  String get zooInfoOpeningTimes => 'Opening times';

  @override
  String get zooInfoOpeningTimesSoon => 'Opening times coming soon.';

  @override
  String get zooInfoWebsite => 'Website';

  @override
  String get zooInfoWebsiteNotAdded => 'Not added yet.';

  @override
  String get zooInfoSocialMedia => 'Social media';

  @override
  String get zooInfoLinksSoon => 'Links coming soon.';

  @override
  String get zooInfoDetails => 'Details';

  @override
  String get zooInfoCountry => 'Country';

  @override
  String get zooInfoUpdated => 'Info updated';

  @override
  String zooInfoAboutPlaceholder(String name) {
    return 'A short description of $name will go here.';
  }

  @override
  String get zooInventoryNoData => 'No data.';

  @override
  String get zooInventoryZooInfo => 'Zoo info';

  @override
  String get zooInventoryMore => 'More';

  @override
  String get zooInventoryReportMissing => 'Report a missing species';

  @override
  String get zooInventoryReportProblem => 'Report a problem';

  @override
  String get zooInventorySearchHint => 'Search species, group, zone...';

  @override
  String get zooInventoryGroup => 'Group';

  @override
  String zooInventoryTitle(String name, int seen, int total) {
    return '$name ($seen/$total)';
  }

  @override
  String get profileNoDataToExport => 'No data to export yet.';

  @override
  String get profileSharingUnavailable =>
      'Sharing unavailable here - data copied to clipboard.';

  @override
  String get profileSetHomeCountry => 'Set home country';

  @override
  String get profileSet => 'Set';

  @override
  String get profileAddFriend => 'Add a friend';

  @override
  String get profileEnterFriendCode => 'Enter a friend code to send a request.';

  @override
  String get profileFriendCode => 'Friend code';

  @override
  String get profileFriends => 'Friends';

  @override
  String get profileAdd => 'Add';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileProfileEditing => 'Profile editing';

  @override
  String get profileSetCountry => 'Set country';

  @override
  String get profileAddFriends => 'Add friends';

  @override
  String get profileExportData => 'Export data (CSV)';

  @override
  String get profileOverview => 'Overview';

  @override
  String get profileAchievements => 'Achievements';

  @override
  String get profileClearLocalZoo => 'Clear local zoo';

  @override
  String get profileVisitToSetLocalZoo => 'Visit a zoo to set your local zoo';

  @override
  String get profileLocalZooNotSet => 'Not set - tap to choose';

  @override
  String get profileLocalZoo => 'Local zoo';

  @override
  String get profileSpeciesSeen => 'Species seen';

  @override
  String get profileZoosVisited => 'Zoos visited';

  @override
  String get profileSightings => 'Sightings';

  @override
  String get profileAchievementsPlaceholder =>
      'Earn awards for milestones like species seen and zoos visited. Only verified sightings will count. Coming soon.';

  @override
  String profileComingSoon(String what) {
    return '$what is coming soon';
  }

  @override
  String profileJoined(String date) {
    return 'Joined $date';
  }

  @override
  String get paywallNoFreeUnlocksLeft => 'No free unlocks left';

  @override
  String get paywallPurchaseComplete => 'Purchase complete';

  @override
  String get paywallPurchaseFailed => 'Purchase failed';

  @override
  String get paywallRestoreRequested => 'Restore requested';

  @override
  String get paywallDevelopmentMode =>
      'Development mode: purchases are simulated and not validated.';

  @override
  String get paywallPremiumHomeCountry => 'Premium (home country)';

  @override
  String get paywallSetHomeCountryToEnable =>
      'Set your home country in Settings to enable.';

  @override
  String get paywallUnlimitedWorldwide => 'Unlimited - every zoo, worldwide';

  @override
  String get paywallUnlimitedSubtitle =>
      'One-time purchase, all zoos everywhere.';

  @override
  String get paywallRestorePurchases => 'Restore purchases';

  @override
  String paywallZooUnlocked(String zooName) {
    return '$zooName unlocked';
  }

  @override
  String paywallUnlockZoo(String zooName) {
    return 'Unlock $zooName';
  }

  @override
  String paywallFirstZoosFree(int count) {
    return 'The first $count zoos are free.';
  }

  @override
  String paywallUseFreeUnlock(int count) {
    return 'Use a free unlock ($count left)';
  }

  @override
  String paywallPremiumAllZoos(String country) {
    return 'Premium - all $country zoos';
  }

  @override
  String paywallUnlocksEveryZooIn(String country) {
    return 'Unlocks every zoo in $country.';
  }

  @override
  String paywallCoversZoosChooseUnlimited(String country, String zooCountry) {
    return 'Covers $country zoos - this zoo is in $zooCountry. Choose Unlimited.';
  }

  @override
  String get errorViewSomethingWentWrong => 'Something went wrong';

  @override
  String get errorViewUnknownError => 'Unknown error';

  @override
  String get reportSheetReportAProblem => 'Report a problem';

  @override
  String get reportSheetThanksReportSaved => 'Thanks - report saved';

  @override
  String get reportSheetSend => 'Send';

  @override
  String get reportSheetShareSubject => 'ZooDex problem report';

  @override
  String get reportSheetCopiedToClipboard => 'Copied report to clipboard';

  @override
  String get reportSheetWhatsWrong => 'What\'s wrong?';

  @override
  String get reportSheetWhichSpecies => 'Which species, and any details?';

  @override
  String get reportSheetNotesOptional => 'Notes (optional)';

  @override
  String get reportSheetMissingHint =>
      'e.g. \"Asian small-clawed otter, in the wetlands house\"';

  @override
  String get reportSheetDescribeProblem => 'Describe the problem';

  @override
  String get reportSheetSaving => 'Saving...';

  @override
  String get reportSheetSubmit => 'Submit';

  @override
  String rangeMapCaption(String species) {
    return '$species - range';
  }

  @override
  String get settingsNightMode => 'Night Mode';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsHomeCountry => 'Home country';

  @override
  String get settingsSetHomeCountry => 'Set home country';

  @override
  String get settingsSet => 'Set';

  @override
  String get settingsPlan => 'Plan';

  @override
  String get settingsPlanUnlimited => 'Unlimited - every zoo';

  @override
  String get settingsRestorePurchases => 'Restore purchases';

  @override
  String get settingsRestoreRequested => 'Restore requested';

  @override
  String get settingsFeedback => 'Feedback';

  @override
  String get settingsReportProblem => 'Report a problem';

  @override
  String get settingsReportProblemSubtitle =>
      'Wrong image, factual error, missing species...';

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String get settingsResetEntitlements => 'Reset entitlements (dev)';

  @override
  String get settingsResetEntitlementsSubtitle =>
      'Clears plan and free unlocks';

  @override
  String get settingsEntitlementsReset => 'Entitlements reset';

  @override
  String get settingsResetOnboarding => 'Reset onboarding (dev)';

  @override
  String get settingsResetOnboardingSubtitle =>
      'Re-shows the first-run flow; also clears home country + free unlocks so the flow takes effect again (keeps your user id)';

  @override
  String get settingsAddAllSpecies => 'Add all species (dev)';

  @override
  String get settingsAddAllSpeciesSubtitle =>
      'Marks every catalogue species seen so the Species tab is fully populated';

  @override
  String get settingsRemoveDevSpecies => 'Remove dev species';

  @override
  String get settingsRemoveDevSpeciesSubtitle =>
      'Removes only the \"add all species\" sightings';

  @override
  String get settingsDevSpeciesRemoved => 'Dev species removed';

  @override
  String get settingsCheckCatalogueData => 'Check catalogue data';

  @override
  String get settingsNoProblemsFound => 'No problems found';

  @override
  String get settingsCatalogueData => 'Catalogue data';

  @override
  String get settingsCatalogueDataNoProblems =>
      'No problems found. Every subspecies/breed points at a species that exists in the catalogue.';

  @override
  String get settingsExportReportsSubtitle =>
      'Share all collected problem reports';

  @override
  String get settingsReportsShareSubject => 'ZooDex problem reports';

  @override
  String get settingsCopiedReports => 'Copied reports to clipboard';

  @override
  String get settingsClearReports => 'Clear reports';

  @override
  String get settingsReportsCleared => 'Reports cleared';

  @override
  String settingsHomeCountrySetSubtitle(String country) {
    return '$country (set once - premium applies here)';
  }

  @override
  String settingsPlanPremium(String country) {
    return 'Premium - all $country zoos';
  }

  @override
  String settingsPlanFree(int used, int max) {
    return 'Free - $used/$max unlocks used';
  }

  @override
  String settingsAddedSpecies(int count) {
    return 'Added $count species to the Dex';
  }

  @override
  String settingsProblemsFound(int count) {
    return '$count problem(s) found - tap for details';
  }

  @override
  String settingsExportReports(int count) {
    return 'Export reports ($count)';
  }

  @override
  String get onboardingCountryTitle => 'Where are you based?';

  @override
  String get onboardingCountrySubtitle =>
      'Your home country. A Premium unlock covers every zoo here. This is set once and can\'t be changed later.';

  @override
  String get onboardingNoCountries => 'No zoo countries available yet.';

  @override
  String get onboardingHomeCountryLabel => 'Home country';

  @override
  String get onboardingLanguageLabel => 'Language';

  @override
  String get onboardingStartExploring => 'Start exploring';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingWelcomeTitle => 'Welcome to ZooDex';

  @override
  String get onboardingWelcomeBody =>
      'Track the animals you spot at the zoos you visit - your own living Pokedex of real wildlife. Let\'s set you up.';

  @override
  String get onboardingNameTitle => 'What should we call you?';

  @override
  String get onboardingNameSubtitle =>
      'Your display name - shown on your profile. You can change it later.';

  @override
  String get onboardingNameLabel => 'Name';

  @override
  String get onboardingUsernameTitle => 'Pick a handle';

  @override
  String get onboardingUsernameSubtitle =>
      'Your @username. It\'s saved for now and becomes your unique handle when accounts go live - so it may need tweaking if it\'s taken.';

  @override
  String get onboardingUsernameLabel => 'Username';

  @override
  String get onboardingUsernameHelper =>
      'Lowercase letters, numbers and underscores.';

  @override
  String get onboardingAvatarTitle => 'Choose an avatar';

  @override
  String get onboardingAvatarSubtitle => 'Picks a look for your profile.';

  @override
  String get onboardingZooTitle => 'Pick your first zoo';

  @override
  String get onboardingZooSubtitle =>
      'Your first three zoos are free - choose one to start (or skip and pick later).';
}
