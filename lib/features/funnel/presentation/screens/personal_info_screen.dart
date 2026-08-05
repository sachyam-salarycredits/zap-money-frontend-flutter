import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// New-flow personal details — read-only PAN names + father, gender, email, Aadhaar.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  final _father = TextEditingController();
  final _email = TextEditingController();
  final _aadhaar = TextEditingController();

  String _gender = '';

  final _emailRegex = RegExp(
    r'^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );
  final _nameLetters = RegExp(r'^[A-Za-z ]+$');

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(
      text: widget.args?['firstname']?.toString() ?? '',
    );
    _last = TextEditingController(
      text: widget.args?['lastname']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _father.dispose();
    _email.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  String? get _dobYmd {
    final direct = widget.args?['dob']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final raw = widget.args?['date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  int? get _ageYears {
    final ymd = _dobYmd;
    if (ymd == null) return null;
    final dob = DateTime.tryParse(ymd);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  bool get _canSubmit {
    return _first.text.trim().isNotEmpty &&
        _father.text.trim().length >= 3 &&
        _gender.isNotEmpty &&
        _email.text.trim().isNotEmpty &&
        _aadhaar.text.trim().length == 12;
  }

  bool _isValidAadhaar(String aadhaar) {
    const d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];
    const p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];
    var c = 0;
    final inverted = aadhaar.split('').map(int.parse).toList().reversed;
    var i = 0;
    for (final val in inverted) {
      c = d[c][p[i % 8][val]];
      i++;
    }
    return c == 0;
  }

  Future<void> _submit() async {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final father = _father.text.trim();
    final email = _email.text.trim().replaceAll(RegExp(r'\s'), '');
    final aadhaar = _aadhaar.text.trim();
    final pan = (widget.args?['pan_number'] ?? widget.args?['pan'])
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';
    final dob = _dobYmd;
    final userType = widget.args?['userType']?.toString() ?? 'Salaried';

    if (first.isEmpty) {
      _toast('Please Enter Valid Name');
      return;
    }
    if (father.length < 3 || !_nameLetters.hasMatch(father)) {
      _toast('Please Enter Valid Fathers Name');
      return;
    }
    if (_gender.isEmpty) {
      _toast('Please select gender to proceed');
      return;
    }
    if (email.isEmpty) {
      _toast('Please enter email to proceed');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _toast('Please enter  email invalid to proceed');
      return;
    }
    if (aadhaar.length != 12) {
      _toast('Please Enter Aadhar Number to proceed');
      return;
    }
    if (!_isValidAadhaar(aadhaar)) {
      _toast('Entered Aadhar Number seems to be wrong');
      return;
    }
    if (pan.isEmpty) {
      _toast('PAN is missing. Go back and enter PAN details.');
      return;
    }
    if (dob == null) {
      _toast('Date of birth is missing. Go back and select DOB.');
      return;
    }

    final years = _ageYears;
    if (years != null) {
      if (userType == 'Student' && (years < 18 || years > 25)) {
        _toast('You do not fall under the required age category');
        return;
      }
      if (userType != 'Student' && (years < 21 || years > 60)) {
        _toast('You do not fall under the required age category');
        return;
      }
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId =
          (await storage.read(StorageKeys.customerId))?.replaceAll('"', '');
      final deviceId =
          (await storage.read(StorageKeys.deviceId))?.replaceAll('"', '');
      final mobile = await storage.read(StorageKeys.mobileNo) ?? '';
      final token = await ref.read(authTokenServiceProvider).verifyAndGetToken();
      final dio = ref.read(dioClientProvider).dio;

      final response = await dio.post(
        ApiEndpoints.storeCustomerInformation,
        data: {
          'device': deviceId,
          'first_name': first,
          'last_name': last,
          'mobile_number': mobile,
          'dob': dob,
          'father_name': father,
          'gender': _gender,
          'email': email,
          'customer_type': userType,
          'pan_number': pan,
          'aadhaar_number': aadhaar,
          'token': token ?? '',
          'driving_license': ' ',
          'voter_id': ' ',
          'partner_id': '',
          if (customerId != null && customerId.isNotEmpty)
            'customer_id': customerId,
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final data = response.data;
      final status = data is Map ? data['status'] : null;
      if (status == 403 || status == '403') {
        _toast(
          data is Map
              ? (data['msg']?.toString() ??
                  'Could not save personal information')
              : 'Could not save personal information',
        );
        return;
      }

      if (data is Map && data['customer_Id'] != null) {
        await storage.write(
          StorageKeys.customerId,
          _jsonEncodeId(data['customer_Id']),
        );
      }

      await ref.read(screenStatusServiceProvider).completePersonalInfo();
      if (mounted) context.go(AppRoutes.equifax);
    } catch (_) {
      _toast('Could not save personal information');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  String _jsonEncodeId(dynamic value) {
    if (value is String) {
      if (value.startsWith('"') && value.endsWith('"')) return value;
      return '"$value"';
    }
    return '"$value"';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);

    return FunnelScaffold(
      title: 'Tell us more\nabout yourself',
      totalSteps: 3,
      activeStep: 2,
      heroAsset: 'assets/images/personalInfo/PersonalInfo.png',
      heroHeight: 120,
      bottom: ZapSubmitButton(
        title: 'Get Credit Score',
        disabled: !_canSubmit || loading,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          _label('First Name'),
          _field(_first, 'First Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Last Name'),
          _field(_last, 'Last Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Father / Spouse Name'),
          _field(
            _father,
            'Enter Father / Spouse Name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('Gender'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final g in const ['Male', 'Female', 'Other']) ...[
                if (g != 'Male') const SizedBox(width: 12),
                Expanded(child: _genderChip(g)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _label('Personal E-mail ID'),
          _field(
            _email,
            'Personal E-mail ID',
            keyboard: TextInputType.emailAddress,
            onChanged: (v) {
              final cleaned = v.replaceAll(RegExp(r'\s'), '');
              if (cleaned != v) {
                _email.value = TextEditingValue(
                  text: cleaned,
                  selection: TextSelection.collapsed(offset: cleaned.length),
                );
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _label('Aadhaar number'),
          _field(
            _aadhaar,
            'Enter your aadhaar number',
            keyboard: TextInputType.number,
            maxLength: 12,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.body(size: 12, color: AppColors.muted),
      ),
    );
  }

  Widget _genderChip(String value) {
    final selected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2A0A5C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accentMint : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(value, style: AppTypography.body(size: 14)),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    bool muted = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: c,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      keyboardType: keyboard,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: AppTypography.body(
        size: 16,
        color: muted ? AppColors.muted : AppColors.white,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFF2A0A5C),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
