import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  final String labelText;
  final String? hintText;
  final IconData? customPrefixIconData;
  final TextEditingController textEditingController;
  final bool isPass;
  final bool isLastTextField;
  final TextInputType? keyboardType;
  final bool isReadOnly;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool? isSearchTextField;
  final Color? iconColor;
  final int? maxLength;
  final String? Function(String?)? validator;
  final bool isNumber;

  const CustomTextField({
    super.key,
    required this.labelText,
    required this.textEditingController,
    this.isSearchTextField,
    this.hintText,
    this.isPass = false,
    this.customPrefixIconData,
    this.keyboardType = TextInputType.name,
    this.isLastTextField = false,
    this.isReadOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.iconColor,
    this.maxLength,
    this.validator,
    this.isNumber = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool isPasswordObscured = true;

  // ✅ Algerian phone validator
  String? _algerianPhoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) {
      return 'Phone number cannot be empty';
    }

    if (cleaned.startsWith('213')) {
      cleaned = '0${cleaned.substring(3)}';
    }

    if (cleaned.length != 10) {
      return 'Phone number must be 10 digits';
    }

    if (!cleaned.startsWith('05') &&
        !cleaned.startsWith('06') &&
        !cleaned.startsWith('07')) {
      return 'Phone must start with 05, 06, or 07';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Apply Algerian phone-specific input formatter when flag is true
    List<TextInputFormatter> inputFormatters = [];
    if (widget.isNumber) {
      inputFormatters.add(
        TextInputFormatter.withFunction((oldValue, newValue) {
          String text = newValue.text;
          text = text.replaceAll(RegExp(r'[^0-9]'), '');

          if (text.startsWith('213')) {
            text = '0${text.substring(3)}';
          }

          if (text.length > 10) {
            text = text.substring(0, 10);
          }

          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }),
      );
    }

    // ✅ Choose validator: custom > algerian phone > default
    String? Function(String?)? effectiveValidator;
    if (widget.validator != null) {
      effectiveValidator = widget.validator;
    } else if (widget.isNumber) {
      effectiveValidator = _algerianPhoneValidator;
    } else {
      effectiveValidator = (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your ${widget.labelText.toLowerCase()}';
        }
        return null;
      };
    }

    final textInputAction = widget.isSearchTextField == true
        ? TextInputAction.search
        : widget.isLastTextField
        ? TextInputAction.next
        : TextInputAction.done;

    Widget? prefixIcon;
    if (widget.isPass) {
      prefixIcon = const Icon(Icons.lock);
    } else if (widget.customPrefixIconData != null) {
      prefixIcon = Icon(widget.customPrefixIconData, color: widget.iconColor);
    }

    // ✅ FIX: Safe suffix icon handling
    Widget? suffixIcon;
    if (widget.isPass) {
      suffixIcon = IconButton(
        onPressed: () {
          setState(() {
            isPasswordObscured = !isPasswordObscured;
          });
        },
        icon: Icon(
          isPasswordObscured ? Icons.visibility : Icons.visibility_off,
        ),
      );
    } else if (!widget.isReadOnly && widget.textEditingController.text.isNotEmpty) {
      suffixIcon = GestureDetector(
        onTap: () {
          widget.textEditingController.clear();
          if (widget.onChanged != null) {
            widget.onChanged!('');
          }
          FocusScope.of(context).unfocus();
        },
        child: const Icon(Icons.clear, color: Colors.red),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: widget.textEditingController,
        maxLength: widget.isNumber ? 10 : widget.maxLength,
        textInputAction: textInputAction, // ✅ Fixed syntax
        obscureText: widget.isPass && isPasswordObscured,
        validator: effectiveValidator,
        keyboardType: widget.isPass
            ? TextInputType.visiblePassword
            : (widget.isNumber ? TextInputType.phone : widget.keyboardType),
        readOnly: widget.isReadOnly,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
        onChanged: (value) {
          if (widget.onChanged != null) {
            widget.onChanged!(value);
          }
        },
        onFieldSubmitted: (value) {
          if (widget.onSubmitted != null) {
            widget.onSubmitted!(value);
          }
        },
      ),
    );
  }
}