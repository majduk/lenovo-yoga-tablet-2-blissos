#!/system/bin/sh
# BlissOS 16.9.7 (Android 13 Go) Tier 1 VOD Debloat & Google Autofill Setup
# Run inside 'adb shell' on Lenovo Yoga Tablet 2 (YT2-1050L / YT2-1050F)

echo "[1/4] Uninstalling heavy bloatware for user 0..."
for p in \
  com.google.android.googlequicksearchbox \
  com.google.android.projection.gearhead \
  io.chaldeaprjkt.gamespace \
  org.omnirom.omnijaws \
  com.android.dreams.basic \
  com.android.wallpaper.livepicker \
  com.android.stk; do
  pm uninstall --user 0 "$p" 2>/dev/null || true
done

echo "[2/4] Freezing background bloatware (keeping core GMS for Widevine VOD & Google Autofill)..."
for p in \
  com.android.vending \
  me.weishu.kernelsu \
  com.android.musicfx \
  org.blissroms.aboutbliss \
  org.lineageos.updater \
  com.google.android.setupwizard \
  com.google.android.apps.restore \
  com.google.android.partnersetup \
  com.google.android.feedback \
  com.android.onetimeinitializer \
  com.android.adservices.api \
  com.android.ondevicepersonalization.services \
  org.lineageos.etar \
  com.android.providers.calendar \
  com.google.android.syncadapters.calendar \
  com.google.android.syncadapters.contacts \
  com.google.android.gm.exchange \
  com.android.contacts \
  com.android.calllogbackup \
  com.android.dialer \
  com.android.messaging \
  com.android.mms.service \
  com.android.cellbroadcastreceiver \
  com.android.cellbroadcastreceiver.module \
  com.android.cellbroadcastservice \
  com.android.simappdialog \
  com.android.carrierdefaultapp \
  com.android.imsserviceentitlement \
  com.android.ons \
  com.android.bips \
  com.android.printspooler \
  com.android.printservice.recommendation \
  com.android.bluetoothmidiservice \
  com.android.bookmarkprovider \
  ink.kscope.parallelspace \
  xtr.keymapper \
  org.blisslabs.blissos.backgrounds \
  com.android.wallpaperbackup; do
  pm disable-user --user 0 "$p" 2>/dev/null || true
  am force-stop "$p" 2>/dev/null || true
done

echo "[3/4] Disabling unneeded GMS background SyncAdapters (keeping chromesync for Passwords)..."
for s in \
  com.google.android.gms.people.sync.PeopleSyncService \
  com.google.android.gms.people.sync.focus.ContactsSyncAdapterService \
  com.google.android.gms.reminders.sync.RemindersSyncService \
  com.google.android.gms.fitness.sync.FitnessSyncAdapterService \
  com.google.android.gms.games.chimera.GamesSyncServiceMainProxy \
  com.google.android.gms.games.chimera.GamesSyncServiceNotificationProxy \
  com.google.android.location.reporting.service.ReportingSyncService; do
  pm disable "com.google.android.gms/$s" 2>/dev/null || true
done

echo "[4/4] Enabling Google Password Manager Autofill & restricting VOD background RAM..."
for c in \
  com.google.android.gms.autofill.service.AutofillService \
  com.google.android.gms.autofill.ui.AutofillActivity \
  com.google.android.gms.autofill.ui.AutofillDialogActivity \
  com.google.android.gms.autofill.ui.AutofillSettingsPrivacyHubActivity \
  com.google.android.gms.autofill.ui.AutofillTransparentActivity \
  com.google.android.gms.autofill.ui.AutofillSettingsActivity \
  com.google.android.gms.autofill.ui.AutofillManagePasswordsActivity \
  com.google.android.gms.autofill.ui.settings.AutofillModernSettingsActivity \
  com.google.android.gms.autofill.service.AutofillImeCoreService \
  com.google.android.gms.autofill.service.AutofillInputMethodServiceProxy \
  com.google.android.gms.auth.api.phone.ui.AutofillConsentActivity \
  com.google.android.gms.auth.api.phone.ui.AutofillSettingsActivity \
  com.google.android.gms.auth.api.phone.ui.AutofillSettingsCollapsingActivity; do
  pm enable "com.google.android.gms/$c" 2>/dev/null || true
done
settings put secure autofill_service com.google.android.gms/com.google.android.gms.autofill.service.AutofillService

for p in com.netflix.mediaclient com.wbd.stream com.aurora.store; do
  cmd appops set "$p" RUN_IN_BACKGROUND ignore 2>/dev/null || true
  cmd appops set "$p" RUN_ANY_IN_BACKGROUND ignore 2>/dev/null || true
done

echo "Done!"
