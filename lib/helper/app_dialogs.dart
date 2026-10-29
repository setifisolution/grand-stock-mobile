import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../manager/routes_manger.dart';
import '../providers/transfer_validation_provider.dart';

import '../screens/auth/login_screen.dart';

class AppDialogs {
  static void showBlocked({
    required BuildContext context,
    VoidCallback? onContactSupport,
    VoidCallback? onDismiss,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.topSlide,
      headerAnimationLoop: true,
      title: '⛔ Account Blocked',
      desc:
          'Your account has been temporarily blocked due to policy violations. Please contact our support team to resolve this issue.',
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      descTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.grey,
        height: 1.4,
      ),
      btnCancelOnPress: onDismiss ?? () {},
      btnOkOnPress: onContactSupport ?? () {},
      btnOkText: 'Contact Support',
      btnCancelText: 'Dismiss',
      btnOkColor: Colors.red,
      btnOk: const Icon(Icons.support_agent, size: 20),
      btnCancelColor: Colors.grey.shade300,
      showCloseIcon: true,
      closeIcon: const Icon(Icons.close, size: 20),
      barrierColor: Colors.black.withOpacity(0.6),
    ).show();
  }

  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String? btnText,
    VoidCallback? onOk,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.topSlide,
      headerAnimationLoop: true,
      title: title,
      desc: message,
      btnOkOnPress: onOk ?? () {},
      btnOkText: btnText ?? 'Continue',
      btnOkColor: Colors.green,
      btnOk: const Icon(Icons.check, size: 20),
    ).show();
  }

  static void showError({
    required BuildContext context,
    required String title,
    required String message,
    String? btnText,
    VoidCallback? onOk,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.topSlide,
      headerAnimationLoop: false,
      title: title,
      desc: message,
      btnOkOnPress: onOk ?? () {},
      btnOkText: btnText ?? 'OK',
      btnOkColor: Colors.red,
      btnOk: const Icon(Icons.error_outline, size: 20),
    ).show();
  }

  static Widget buildLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator.adaptive(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),
      ),
    );
  }

  static void showSpecialProductDialog({
    required BuildContext context,
    VoidCallback? onContactPressed,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      headerAnimationLoop: true,
      animType: AnimType.scale,
      title: 'Produit Spécial',
      desc: 'Veuillez contacter votre commercial pour la quantité souhaitée.',
      btnOkText: 'Nous Contacter',
      btnCancelText: 'Fermer',
      btnCancelOnPress: () {},
      showCloseIcon: true,
      btnOkOnPress: () {
        if (onContactPressed != null) {
          onContactPressed();
        }
      },
    ).show();
  }

  static void showLogoutDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Déconnexion',
      desc: 'Voulez-vous vraiment vous déconnecter ?',
      btnCancelOnPress: () {
        Navigator.pop(context);
      },
      btnOkOnPress: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      },
      btnCancelText: 'Annuler',
      btnOkText: 'Oui',
      btnCancelColor: Colors.grey[400],
      btnOkColor: Colors.redAccent,
    ).show();
  }

  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required TransferValidationProvider provider,
  }) {
    final completer = Completer<bool?>();

    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: 'Confirmer la validation',
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vous allez valider ${provider.acceptedCount} produit(s):'),
              const SizedBox(height: 8),
              ...provider.products
                  .where((p) => p.isAccepted)
                  .take(5)
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text('• ${p.name} (Lot: ${p.lot})'),
                    ),
                  ),
              if (provider.acceptedCount > 5)
                Text('• et ${provider.acceptedCount - 5} autre(s)...'),
            ],
          ),
        ),
      ),
      headerAnimationLoop: false,
      btnCancelText: 'Annuler',
      btnOkText: 'Valider',
      btnCancelColor: Colors.grey[600],
      btnOkColor: Colors.green,
      btnCancelOnPress: () => completer.complete(false),
      btnOkOnPress: () => completer.complete(true),
    ).show();

    return completer.future;
  }

  static void showInventoryClosedDialog({
    required BuildContext context,
    VoidCallback? submitAccepted,
    bool? hasShownClosedDialog ,
  }) {
    try {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        headerAnimationLoop: true,
        title: 'Inventaire Fermé',
        desc:
            "L'inventaire est maintenant fermé. Veuillez sauvegarder vos données pour ne rien perdre.",
        btnOkText: 'Sauvegarder',
        btnOkColor: Colors.green.shade600,
        btnOkIcon: Icons.save_alt,
        btnCancelText: 'Continuer sans sauvegarder',
        btnCancelColor: Colors.grey.shade300,
        btnOkOnPress: () {
          if (submitAccepted != null) {
            submitAccepted();
            Routes.mainRoute;
          }
        },
        onDismissCallback: (_) => hasShownClosedDialog = false,
      )..show();
    } catch (e) {
      hasShownClosedDialog = false;
    }
  }
}
