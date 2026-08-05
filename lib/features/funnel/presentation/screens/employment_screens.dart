import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class EmployerDetailsScreen extends ConsumerStatefulWidget {
  const EmployerDetailsScreen({super.key, this.isFrom});

  /// RN `isFrom` — e.g. `unlockOffer` re-runs credit decision via waiting.
  final String? isFrom;

  @override
  ConsumerState<EmployerDetailsScreen> createState() =>
      _EmployerDetailsScreenState();
}

class _EmployerDetailsScreenState extends ConsumerState<EmployerDetailsScreen> {
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _locality = TextEditingController();
  final _sublocality = TextEditingController();
  final _address = TextEditingController();
  final _emailRegex = RegExp(
    r'^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );

  /// RN `buttonPressed` — "I don't have an office Email ID".
  bool _noOfficeEmail = false;
  bool _lookingUpPin = false;
  XFile? _idFront;
  XFile? _idBack;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _company.dispose();
    _email.dispose();
    _pin.dispose();
    _city.dispose();
    _state.dispose();
    _locality.dispose();
    _sublocality.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _emailOk =>
      _email.text.trim().isNotEmpty && _emailRegex.hasMatch(_email.text.trim());

  bool get _officeAddressOk =>
      _pin.text.trim().length == 6 &&
      _city.text.trim().isNotEmpty &&
      _state.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty;

  bool get _canContinue {
    if (_company.text.trim().isEmpty) return false;
    if (!_officeAddressOk) return false;
    if (_noOfficeEmail) {
      return _idFront != null && _idBack != null;
    }
    return _emailOk;
  }

  Future<void> _onPostalChanged(String raw) async {
    final pin = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (pin != _pin.text) {
      _pin.value = TextEditingValue(
        text: pin,
        selection: TextSelection.collapsed(offset: pin.length),
      );
    }
    setState(() {});
    if (pin.length != 6) return;
    setState(() => _lookingUpPin = true);
    try {
      final dio = ref.read(dioClientProvider).dio;
      final cityRes = await dio.post(
        ApiEndpoints.fetchCity,
        data: FormData.fromMap({'pincode': pin}),
      );
      final cityRoot = cityRes.data;
      if (cityRoot is Map && cityRoot['status_code'] == 200) {
        final result = cityRoot['result'];
        final data = result is Map ? result['data'] : null;
        if (data is Map) {
          final city = data['city']?.toString() ?? '';
          if (city.isNotEmpty) _city.text = city;
        }
      }

      final locRes = await dio.post(
        ApiEndpoints.getLocalities,
        data: {'pincode': pin},
        options: Options(contentType: Headers.jsonContentType),
      );
      final locRoot = locRes.data;
      if (locRoot is Map && locRoot['status_code'] == 200) {
        final result = locRoot['result'];
        final list = result is Map ? result['locality'] : null;
        if (list is List && list.isNotEmpty) {
          final first = list.first.toString();
          if (first.isNotEmpty) {
            _locality.text = first;
            final subRes = await dio.post(
              ApiEndpoints.getSubLocalities,
              data: {'pincode': pin, 'locality': first},
              options: Options(contentType: Headers.jsonContentType),
            );
            final subRoot = subRes.data;
            if (subRoot is Map && subRoot['status_code'] == 200) {
              final subResult = subRoot['result'];
              final subs = subResult is Map ? subResult['sublocality'] : null;
              if (subs is List && subs.isNotEmpty) {
                _sublocality.text = subs.first.toString();
              }
            }
          }
        }
      }

      try {
        final gov = await dio.get(
          'https://api.data.gov.in/resource/0a076478-3fd3-4e2c-b2d2-581876f56d77',
          queryParameters: {
            'format': 'json',
            'api-key':
                '579b464db66ec23bdd000001be9925f848ef448249d6231c74b87637',
            'filters[pincode]': pin,
          },
          options: Options(
            extra: {'clearHeader': true},
            contentType: Headers.jsonContentType,
          ),
        );
        final govRoot = gov.data;
        if (govRoot is Map && govRoot['status']?.toString() == 'ok') {
          final records = govRoot['records'];
          if (records is List && records.isNotEmpty && records.first is Map) {
            final state = (records.first as Map)['statename']?.toString() ?? '';
            if (state.isNotEmpty) _state.text = state;
          }
        }
      } catch (_) {}
    } catch (_) {
      // Manual entry still allowed.
    } finally {
      if (mounted) setState(() => _lookingUpPin = false);
    }
  }

  Future<void> _pickId({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF4A2B8C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  front
                      ? 'Employee ID card front side'
                      : 'Employee ID card back side',
                  style: AppTypography.body(size: 16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _pickSourceButton(
                        icon: Icons.photo_camera_outlined,
                        label: 'Camera',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickSourceButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      if (front) {
        _idFront = file;
      } else {
        _idBack = file;
      }
    });
  }

  Widget _pickSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF3E1982),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.body(size: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadEmployeeId({
    required Dio dio,
    required String customerId,
    required String? sfCustomerId,
    required String docName,
    required XFile file,
  }) async {
    final form = FormData.fromMap({
      'document_name': docName,
      'customer_id': customerId,
      if (sfCustomerId != null && sfCustomerId.isNotEmpty)
        'sf_customer_id': sfCustomerId,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      ),
    });
    await dio.post(
      ApiEndpoints.saveDocument,
      data: form,
    );
  }

  Future<void> _submit() async {
    final company = _company.text.trim();
    if (company.isEmpty) {
      _toast('Please enter employername');
      return;
    }
    if (_pin.text.trim().length != 6) {
      _toast('Please enter pincode');
      return;
    }
    if (_city.text.trim().isEmpty) {
      _toast('Please enter city');
      return;
    }
    if (_state.text.trim().isEmpty) {
      _toast('Please enter state');
      return;
    }
    if (_address.text.trim().isEmpty) {
      _toast('Please enter address');
      return;
    }
    if (!_noOfficeEmail) {
      if (_email.text.trim().isEmpty) {
        _toast('Please enter email');
        return;
      }
      if (!_emailOk) {
        _toast('Please enter the valid email Id');
        return;
      }
    } else {
      if (_idFront == null || _idBack == null) {
        _toast('Please enter idcard');
        return;
      }
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId =
          (await storage.read(StorageKeys.customerId))?.replaceAll('"', '');
      final sfCustomerId =
          (await storage.read(StorageKeys.sfCustomerId))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        _toast('Missing customer id');
        return;
      }

      final dio = ref.read(dioClientProvider).dio;

      if (_noOfficeEmail) {
        await _uploadEmployeeId(
          dio: dio,
          customerId: customerId,
          sfCustomerId: sfCustomerId,
          docName: 'employeeid_front',
          file: _idFront!,
        );
        await _uploadEmployeeId(
          dio: dio,
          customerId: customerId,
          sfCustomerId: sfCustomerId,
          docName: 'employeeid_back',
          file: _idBack!,
        );
      }

      // RN insertAddressInfo → StoreOfficeAddress (before StoreEmpInfo on unlock)
      await dio.post(
        ApiEndpoints.storeOfficeAddress,
        data: {
          'customer_id': customerId,
          'pincode': _pin.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'locality': _locality.text.trim().isEmpty
              ? _city.text.trim()
              : _locality.text.trim(),
          'sublocality': _sublocality.text.trim().isEmpty
              ? _city.text.trim()
              : _sublocality.text.trim(),
          'address': _address.text.trim(),
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      // RN getEmployerDetails → StoreEmpInfo
      await dio.post(
        ApiEndpoints.storeEmpInfo,
        data: {
          'company_name': company,
          'sf_record_id': null,
          'customer_id': customerId,
          'official_email': _noOfficeEmail ? '' : _email.text.trim(),
          'parent_phone': '',
          'payslippassword': '',
          'user_type': 'Salaried',
          'employer_name': company,
          'employer_email': _noOfficeEmail ? '' : _email.text.trim(),
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      await ref.read(screenStatusServiceProvider).completeEmployer();
      if (!mounted) return;
      // Unlock path (and RN default post-employer): re-run CD on Waiting.
      // Mid-funnel / profile edit still lands on bank when not unlocking.
      if (widget.isFrom == 'unlockOffer') {
        context.go(AppRoutes.waiting);
      } else if (widget.isFrom == 'editProfile') {
        context.go(AppRoutes.profile);
      } else {
        context.go(AppRoutes.bankDetails);
      }
    } catch (_) {
      _toast('Could not save employer details');
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

    return FunnelScaffold(
      title: 'Employer details',
      totalSteps: 3,
      activeStep: 1,
      bottom: ZapSubmitButton(
        title: 'Continue',
        disabled: !_canContinue || loading,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('Company name'),
          _input(_company, 'Enter your company name', onChanged: (_) {
            setState(() {});
          }),
          const SizedBox(height: 16),
          _label('Office pin code'),
          _input(
            _pin,
            'Enter 6-digit pin code',
            keyboard: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: _onPostalChanged,
            suffix: _lookingUpPin
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentMint,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _label('City'),
          _input(_city, 'City', onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          _label('State'),
          _input(_state, 'State', onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          _label('Full address'),
          _input(
            _address,
            'Enter full office address',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (!_noOfficeEmail) ...[
            _label('Office Email ID'),
            _input(
              _email,
              'Enter your office Email-ID',
              keyboard: TextInputType.emailAddress,
              onChanged: (v) {
                final cleaned = v.replaceAll(RegExp(r'\s'), '');
                if (cleaned != v) {
                  _email.value = TextEditingValue(
                    text: cleaned,
                    selection:
                        TextSelection.collapsed(offset: cleaned.length),
                  );
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
          InkWell(
            onTap: () {
              setState(() {
                _noOfficeEmail = !_noOfficeEmail;
                if (_noOfficeEmail) {
                  _email.clear();
                } else {
                  _idFront = null;
                  _idBack = null;
                }
              });
            },
            child: Row(
              children: [
                Icon(
                  _noOfficeEmail
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: _noOfficeEmail
                      ? AppColors.accentMint
                      : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "I don't have an office Email ID",
                    style: AppTypography.body(size: 13),
                  ),
                ),
              ],
            ),
          ),
          if (_noOfficeEmail) ...[
            const SizedBox(height: 20),
            Text(
              'Upload your office ID',
              style: AppTypography.body(size: 13, weight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _idTile(
                    label: 'ID Front side',
                    file: _idFront,
                    onPick: () => _pickId(front: true),
                    onClear: () => setState(() => _idFront = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _idTile(
                    label: 'ID Back side',
                    file: _idBack,
                    onPick: () => _pickId(front: false),
                    onClear: () => setState(() => _idBack = null),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _idTile({
    required String label,
    required XFile? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return AspectRatio(
      aspectRatio: 1.4,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3E1982),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload, color: Color(0xFFAC9FC6)),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: AppTypography.body(
                        size: 13,
                        color: const Color(0xFFAC9FC6),
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(file.path), fit: BoxFit.cover),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onClear,
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.close, size: 14, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      cursorColor: Colors.white,
      style: AppTypography.body(size: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFF2A0A5C),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class CollegeDetailsScreen extends ConsumerStatefulWidget {
  const CollegeDetailsScreen({super.key});

  @override
  ConsumerState<CollegeDetailsScreen> createState() =>
      _CollegeDetailsScreenState();
}

class _CollegeDetailsScreenState extends ConsumerState<CollegeDetailsScreen> {
  final _college = TextEditingController();

  @override
  void dispose() {
    _college.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_college.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter college name')),
      );
      return;
    }
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId =
          (await storage.read(StorageKeys.customerId))?.replaceAll('"', '');
      await ref.read(dioClientProvider).dio.post(
            ApiEndpoints.storeEmpInfo,
            data: {
              'customer_id': customerId,
              'college_name': _college.text.trim(),
              'user_type': 'Student',
            },
            options: Options(contentType: Headers.jsonContentType),
          );
      await ref.read(screenStatusServiceProvider).completeCollege();
      if (mounted) context.go(AppRoutes.bankDetails);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save college details')),
        );
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'College details',
      bottom: ZapSubmitButton(title: 'Continue', onPressed: _submit),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _college,
          cursorColor: Colors.white,
          style: AppTypography.body(size: 16),
          decoration: InputDecoration(
            hintText: 'College name',
            hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
