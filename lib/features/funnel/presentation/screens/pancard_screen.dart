import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// New-flow PAN screen — PAN + wheel DOB, then `/PanDetails`.
class PancardScreen extends ConsumerStatefulWidget {
  const PancardScreen({super.key, this.userType});

  final String? userType;

  @override
  ConsumerState<PancardScreen> createState() => _PancardScreenState();
}

class _PancardScreenState extends ConsumerState<PancardScreen> {
  final _pan = TextEditingController();
  final _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

  late DateTime _dob;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dob = DateTime(now.year - 18, now.month, now.day);
  }

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  DateTime get _maxDob {
    final now = DateTime.now();
    return DateTime(now.year - 18, now.month, now.day);
  }

  Future<void> _continue() async {
    final value = _pan.text.trim().toUpperCase();
    if (!_panRegex.hasMatch(value)) {
      _toast('Please enter a valid PAN');
      return;
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.post(
        ApiEndpoints.panDetails,
        data: {'PanNo': value},
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = response.data;
      final status = data is Map ? data['Statuscode'] : null;
      if (status != 200 && status != '200') {
        _toast('Please provide valid PAN Number');
        return;
      }

      final firstName =
          data is Map ? (data['firstName']?.toString() ?? '') : '';
      final lastName = data is Map ? (data['lastName']?.toString() ?? '') : '';

      if (!mounted) return;
      context.push(AppRoutes.personalInfo, extra: {
        'userType': widget.userType ?? 'Salaried',
        'pan': value,
        'pan_number': value,
        'firstname': firstName,
        'lastname': lastName,
        'date': _dob.toIso8601String(),
        'dob': DateFormat('yyyy-MM-dd').format(_dob),
      });
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['Error'] ?? e.response!.data['msg'])?.toString()
          : null;
      _toast(msg ?? 'Could not verify PAN. Please try again.');
    } catch (_) {
      _toast('Could not verify PAN. Please try again.');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);
    final panOk = _panRegex.hasMatch(_pan.text.trim().toUpperCase());

    return FunnelScaffold(
      title: 'Verify your\nPAN card',
      totalSteps: 4,
      activeStep: 1,
      heroAsset: 'assets/images/personalInfo/pandetail.png',
      heroHeight: 120,
      bottom: ZapSubmitButton(
        title: 'Continue',
        disabled: !panOk || loading,
        onPressed: _continue,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          TextField(
            controller: _pan,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            cursorColor: Colors.white,
            style: AppTypography.body(size: 18),
            onChanged: (_) => setState(() {}),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: _fieldDecoration('Enter your 10 digit PAN no.'),
          ),
          const SizedBox(height: 28),
          Text(
            'Date of Birth',
            style: AppTypography.body(size: 14, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: Localizations.override(
              context: context,
              locale: const Locale('en', 'US'),
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  primaryColor: Colors.white,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontFamily: AppTypography.family,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime:
                      _dob.isAfter(_maxDob) ? _maxDob : _dob,
                  minimumDate: DateTime(1900, 1, 1),
                  maximumDate: _maxDob,
                  dateOrder: DatePickerDateOrder.dmy,
                  onDateTimeChanged: (d) => setState(() => _dob = d),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
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
    );
  }
}
