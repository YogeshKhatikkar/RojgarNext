// lib/features/jobs/presentation/screens/add_job_screen.dart
// ✅ ULTIMATE AI-BASED TABBED DESIGN - Full CRUD preserved
// ✅ All original features kept intact + modern tab UI like basic_details_screen
// ✅ 8 Tabs: Basic | Vacancy | Age & Fees | Timeline | Work | Interview | Notification | Extras

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnext/core/config/api_config.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/master_date/locations.dart';
import 'package:rojgarnext/features/notification/service/notification_service.dart';
import 'package:rojgarnext/core/master_date/education.dart';

class AddJobScreen extends StatefulWidget {
  final String adminRole;
  final VoidCallback? onJobAdded;

  const AddJobScreen({super.key, this.adminRole = 'admin', this.onJobAdded});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen>
    with SingleTickerProviderStateMixin {
  static const int maxFileSizeMB = 50;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();

  // ==================== TAB CONTROL ====================
  static const int _tabCount = 8;
  late TabController _tabController;
  int _currentTabIndex = 0;

  final List<IconData> _tabIcons = const [
    Icons.business,
    Icons.people,
    Icons.calendar_today,
    Icons.date_range,
    Icons.work_outline,
    Icons.people_alt,
    Icons.notifications,
    Icons.info_outline,
  ];

  final List<String> _tabLabels = const [
    'Basic',
    'Vacancy',
    'Age/Fees',
    'Timeline',
    'Work',
    'Interview',
    'Notification',
    'Extras',
  ];

  String get _safeTabLabel {
    final idx = _currentTabIndex.clamp(0, _tabLabels.length - 1);
    return _tabLabels[idx];
  }

  IconData get _safeTabIcon {
    final idx = _currentTabIndex.clamp(0, _tabIcons.length - 1);
    return _tabIcons[idx];
  }

  // ==================== BASIC CONTROLLERS ====================
  final organizationCtrl = TextEditingController();
  final postNameCtrl = TextEditingController();
  final cityVillageCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final lastDateCtrl = TextEditingController();
  final postDateCtrl = TextEditingController();

  final applyWithUsUrlCtrl = TextEditingController();
  bool hasApplyWithUs = false;
  final websiteUrlCtrl = TextEditingController();

  // ==================== OFFICIAL NOTIFICATION SECTION ====================
  final officialNotificationUrlCtrl = TextEditingController();
  bool hasOfficialNotificationLink = false;
  String? selectedFileName;
  Uint8List? selectedFileBytes;
  String? selectedFileMimeType;
  bool isUploading = false;
  bool hasAdvertisementFile = false;

  // ==================== AGE LIMIT ====================
  final ageCalcDateCtrl = TextEditingController();
  final ageRelaxationCtrl = TextEditingController();

  // ==================== AGE RELAXATION WITH DROPDOWN ====================
  bool _hasAgeRelaxation = false;
  bool _isEditingRelaxation = false;
  String? _editingRelaxationCategory;
  final TextEditingController relaxationCategoryCtrl = TextEditingController();
  final TextEditingController relaxationYearsCtrl = TextEditingController();
  final Map<String, TextEditingController> relaxationControllers = {};
  final Map<String, String> relaxationValues = {};

  final List<String> relaxationCategories = const [
    'General/UR',
    'OBC',
    'SC',
    'ST',
    'EWS',
    'PWD',
    'Female',
    'ESM',
    'Ex-Serviceman',
    'Sports Person',
    'Kashmiri Migrant',
    'J&K Domicile',
  ];

  // ==================== APPLICATION FEES SECTION ====================
  bool _hasApplicationFees = false;
  final Map<String, TextEditingController> feesControllers = {};
  final Map<String, String> feesValues = {};
  String? _editingFeeCategory;
  bool _isEditingFee = false;
  final TextEditingController feeCategoryCtrl = TextEditingController();
  final TextEditingController feeAmountCtrl = TextEditingController();

  final List<String> predefinedFeeCategories = const [
    'General/UR',
    'OBC',
    'SC',
    'ST',
    'EWS',
    'PWD',
    'Female',
    'ESM',
    'Transgender',
    'Other',
  ];

  // ==================== MULTIPLE POSTS ====================
  List<Map<String, dynamic>> multiplePosts = [];
  final postNameCtrl2 = TextEditingController();
  final vacancyCtrl = TextEditingController();
  String? selectedQualificationFromEducation;
  String? selectedQualificationSubOption;
  String? selectedDegreeStream;
  String? selectedDegreeName;
  List<String> _qualificationSubOptions = [];
  List<String> _degreeStreams = [];
  List<String> _degreeNames = [];
  final postAgeMinCtrl = TextEditingController();
  final postAgeMaxCtrl = TextEditingController();
  final otherQualificationCtrl = TextEditingController();
  final TextEditingController experienceDetailsCtrl = TextEditingController();
  int? _editingPostIndex;
  bool _isEditingPost = false;

  // ==================== PAY SCALE (Per Post with Dropdown) ====================
  int? _selectedPostForPayScale;
  final TextEditingController payScaleCtrl = TextEditingController();
  final TextEditingController gradePayCtrl = TextEditingController();
  final TextEditingController payBandCtrl = TextEditingController();
  final TextEditingController minSalaryCtrl = TextEditingController();
  final TextEditingController maxSalaryCtrl = TextEditingController();
  int? _editingPayScaleIndex;
  bool _isEditingPayScale = false;

  // ==================== CATEGORY VACANCY ====================
  bool _hasCategoryVacancy = false;
  int? _editingCategoryPostIndex;
  int? _editingCategoryIndex;
  bool _isEditingCategory = false;
  final TextEditingController categoryNameCtrl = TextEditingController();
  final TextEditingController categoryVacancyCtrl = TextEditingController();

  final List<String> predefinedCategories = const [
    'General/UR',
    'OBC',
    'SC',
    'ST',
    'EWS',
    'PWD',
    'Female',
    'ESM',
  ];

  // ==================== APPLICATION DATES ====================
  final TextEditingController applicationStartDateCtrl =
      TextEditingController();
  final TextEditingController applicationEndDateCtrl = TextEditingController();

  // ==================== OFFICIAL DETAILS ====================
  final TextEditingController notificationNumberCtrl = TextEditingController();
  final TextEditingController notificationDateCtrl = TextEditingController();
  String selectedApplicationMode = 'Online';
  final List<String> applicationModes = ['Online', 'Offline', 'Both'];

  // ==================== EXAM CITIES ====================
  List<String> examCities = [];
  final TextEditingController examCityCtrl = TextEditingController();

  // ==================== PHYSICAL ELIGIBILITY ====================
  bool _hasPhysicalRequirement = false;
  final TextEditingController minHeightCtrl = TextEditingController();
  final TextEditingController minHeightFemaleCtrl = TextEditingController();
  final TextEditingController minChestCtrl = TextEditingController();
  final TextEditingController maxWeightCtrl = TextEditingController();
  final TextEditingController physicalRelaxationCtrl = TextEditingController();

  // ==================== MEDICAL STANDARDS ====================
  bool _hasMedicalRequirement = false;
  final TextEditingController medicalStandardsCtrl = TextEditingController();

  // ==================== TRAINING DETAILS ====================
  bool _hasTraining = false;
  final TextEditingController trainingDurationCtrl = TextEditingController();
  final TextEditingController trainingStipendCtrl = TextEditingController();
  final TextEditingController trainingLocationCtrl = TextEditingController();

  // ==================== ADDITIONAL ====================
  final TextEditingController whatsappNumberCtrl = TextEditingController();
  final TextEditingController telegramChannelCtrl = TextEditingController();

  // ==================== EDUCATION ====================
  final List<String> educationLevels = [
    'No Formal Education',
    'Below 5th',
    '5th Pass',
    '8th Pass',
    '10th Pass',
    '12th Pass',
    'ITI',
    'Diploma',
    'Graduation',
    'Post Graduation',
    'PhD',
    'Vocational Training',
    'Any Graduate',
    'Any Post Graduate',
  ];

  final TextEditingController educationDetailsCtrl = TextEditingController();
  String selectedEducation = 'Any Graduate';

  bool isFresherEligible = true;
  bool isExperiencedEligible = true;

  List<String> selectedBenefits = [];
  final List<String> availableBenefits = const [
    'Health Insurance',
    'Provident Fund',
    'Gratuity',
    'Bonus',
    'Travel Allowance',
    'House Rent Allowance',
    'Food Allowance',
    'Education Allowance',
    'Leave Encashment',
    'Flexible Timing',
    'Work From Home',
    'Free Transport',
    'Free Accommodation',
    'Medical Facilities',
    'Training Programs',
    'Career Growth',
    'Performance Bonus',
    'Stock Options',
    'Mobile Allowance',
    'Internet Allowance',
  ];

  final List<String> workSchedules = const [
    'Full Time',
    'Part Time',
    'Contractual',
    'Temporary',
    'Permanent',
    'Freelance',
    'Internship',
    'Volunteer',
  ];
  String selectedWorkSchedule = 'Full Time';

  final List<String> shifts = const [
    'Day Shift',
    'Night Shift',
    'Rotational Shift',
    'Flexible Shift',
    'Split Shift',
    'On Call',
  ];
  String selectedShift = 'Day Shift';

  final List<String> workingDays = const [
    'Monday to Friday',
    'Monday to Saturday',
    '5 Days a Week',
    '6 Days a Week',
    'Alternate Days',
    'Rotational Off',
  ];
  String selectedWorkingDays = 'Monday to Friday';

  List<String> selectedLanguages = [];
  final List<String> availableLanguages = const [
    'Hindi',
    'English',
    'Marathi',
    'Bengali',
    'Telugu',
    'Tamil',
    'Gujarati',
    'Kannada',
    'Malayalam',
    'Punjabi',
    'Urdu',
    'Odia',
    'Assamese',
  ];
  final TextEditingController otherLanguagesCtrl = TextEditingController();

  final TextEditingController interviewVenueCtrl = TextEditingController();
  final TextEditingController interviewDateCtrl = TextEditingController();
  final TextEditingController interviewTimeCtrl = TextEditingController();
  bool isInterviewOnline = false;
  final TextEditingController interviewLinkCtrl = TextEditingController();
  List<String> interviewDocuments = [];
  final List<String> requiredDocuments = const [
    'Resume/CV',
    'Educational Certificates',
    'Experience Certificates',
    'Aadhar Card',
    'PAN Card',
    'Passport Size Photo',
    'Caste Certificate',
    'Disability Certificate',
    'Ex-Serviceman Certificate',
    'Income Certificate',
  ];

  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController contactDesignationCtrl = TextEditingController();
  final TextEditingController contactEmailCtrl = TextEditingController();
  final TextEditingController contactPhoneCtrl = TextEditingController();
  final TextEditingController importantNotesCtrl = TextEditingController();
  final TextEditingController termsAndConditionsCtrl = TextEditingController();

  List<String> selectionStages = [];
  final List<String> availableStages = const [
    'Application Screening',
    'Written Exam',
    'Skill Test',
    'Group Discussion',
    'Personal Interview',
    'HR Interview',
    'Technical Interview',
    'Medical Examination',
    'Document Verification',
    'Final Selection',
  ];
  final TextEditingController selectionProcessDetailsCtrl =
      TextEditingController();

  bool hasBond = false;
  final TextEditingController bondDurationCtrl = TextEditingController();
  final TextEditingController bondAmountCtrl = TextEditingController();
  final TextEditingController bondTermsCtrl = TextEditingController();

  final List<String> urgencyLevels = const [
    'Immediate',
    'Urgent',
    'Normal',
    'Long Term',
  ];
  String selectedUrgency = 'Normal';
  final List<String> genderPreferences = const [
    'Any',
    'Male',
    'Female',
    'Transgender',
  ];
  String selectedGenderPreference = 'Any';
  bool isFullyRemote = false;
  bool isHybrid = false;

  final TextEditingController admitCardDateCtrl = TextEditingController();
  final TextEditingController examDateCtrl = TextEditingController();
  final TextEditingController resultDateCtrl = TextEditingController();
  final TextEditingController officialWebsiteCtrl = TextEditingController();
  final TextEditingController helplineNumberCtrl = TextEditingController();
  final TextEditingController helplineEmailCtrl = TextEditingController();

  final List<String> jobTypes = const [
    'private',
    'remote',
    'hybrid',
    'government',
  ];
  final List<String> jobLevels = const [
    'entry',
    'mid',
    'senior',
    'lead',
    'executive',
  ];
  final List<String> categories = const [
    'IT',
    'Marketing',
    'Finance',
    'HR',
    'Engineering',
    'Teaching',
    'Healthcare',
    'Government',
    'Banking',
    'Defense',
    'Sales',
    'Operations',
  ];

  String jobType = 'private';
  String jobLevel = 'mid';
  String category = 'IT';

  String? _selectedCountry;
  String? _selectedState;
  String? _selectedDistrict;
  List<String> _countries = [];
  List<String> _states = [];
  List<String> _districts = [];

  bool isLoading = false;
  bool _showMultiplePosts = false;
  bool _useCurrentLocation = false;
  String _locationStatus = '';
  bool _isGettingLocation = false;
  bool _isGeocoding = false;
  Map<String, dynamic>? _geocodedResult;
  String _geocodingStatus = '';

  // ==================== EDUCATION MASTER DATA MAPS ====================
  final Map<String, List<String>> _qualificationSubOptionsMap = {
    'ITI': EducationMasterData.getItiTradeNames(),
    'Diploma': EducationMasterData.getDiplomaCourseNames(),
    'Vocational Training': EducationMasterData.getCertificationNames(),
  };

  final Map<String, List<String>> _degreeStreamsMap = {
    'Graduation': const [
      'B.Tech', 'B.E.', 'B.Sc', 'B.Com', 'B.A.', 'BBA', 'BCA', 'B.Pharma',
      'B.Arch', 'B.Des', 'B.Plan', 'B.H.M.', 'B.Ed', 'B.P.Ed', 'B.Lib',
      'B.F.A.', 'B.J.M.C.', 'B.S.W.', 'LL.B.', 'B.A.LL.B', 'B.Com.LL.B',
      'B.B.A.LL.B', 'MBBS', 'BDS', 'BHMS', 'BAMS', 'BUMS', 'B.V.Sc.',
      'B.P.T.', 'B.O.T.', 'B.Sc Nursing', 'B.Optom', 'B.M.L.T.',
      'B.Sc Agriculture', 'B.Sc Horticulture', 'B.Sc Forestry', 'B.F.Sc',
    ],
    'Post Graduation': const [
      'M.Tech', 'M.E.', 'M.Sc', 'M.Com', 'M.A.', 'MBA', 'MCA', 'M.Pharma',
      'M.Arch', 'M.Des', 'M.Plan', 'M.H.M.', 'M.Ed', 'M.P.Ed', 'M.Lib',
      'M.F.A.', 'M.J.M.C.', 'M.S.W.', 'LL.M.', 'MD', 'MS', 'MDS', 'M.P.T.',
      'M.Sc Nursing',
    ],
    'PhD': const ['PhD', 'M.Phil', 'D.Sc', 'D.Litt', 'DBA', 'D.M.A.', 'Ed.D', 'D.Eng'],
  };

  final Map<String, List<String>> _degreeSubjectsMap = {
    'B.Tech': EducationMasterData.getEngineeringBranches(),
    'B.E.': EducationMasterData.getEngineeringBranches(),
    'M.Tech': EducationMasterData.getEngineeringBranches(),
    'M.E.': EducationMasterData.getEngineeringBranches(),
    'B.Sc': EducationMasterData.getScienceSubjects(),
    'M.Sc': EducationMasterData.getScienceSubjects(),
    'B.Com': EducationMasterData.getCommerceSubjects(),
    'M.Com': EducationMasterData.getCommerceSubjects(),
    'B.A.': EducationMasterData.getArtsSubjects(),
    'M.A.': EducationMasterData.getArtsSubjects(),
    'BBA': EducationMasterData.getManagementSubjects(),
    'MBA': EducationMasterData.getManagementSubjects(),
    'BCA': EducationMasterData.getComputerSubjects(),
    'MCA': EducationMasterData.getComputerSubjects(),
    'MBBS': EducationMasterData.getMedicalSubjects(),
    'BDS': EducationMasterData.getMedicalSubjects(),
    'BHMS': EducationMasterData.getMedicalSubjects(),
    'BAMS': EducationMasterData.getMedicalSubjects(),
    'B.Pharma': EducationMasterData.getMedicalSubjects(),
    'M.Pharma': EducationMasterData.getMedicalSubjects(),
    'LL.B.': EducationMasterData.getLawSubjects(),
    'LL.M.': EducationMasterData.getLawSubjects(),
    'B.Sc Agriculture': EducationMasterData.getAgricultureSubjects(),
    'PhD': [],
    'M.Phil': [],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_currentTabIndex != _tabController.index) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    _loadCountries();
    _setupLocationListeners();

    for (var category in relaxationCategories) {
      relaxationControllers[category] = TextEditingController();
      relaxationValues[category] = '';
    }

    for (var category in predefinedFeeCategories) {
      feesControllers[category] = TextEditingController();
      feesValues[category] = '';
    }
    _updateQualificationSubOptions();
  }

  void _updateQualificationSubOptions() {
    setState(() {
      final selected = selectedQualificationFromEducation;
      selectedQualificationSubOption = null;
      selectedDegreeStream = null;
      selectedDegreeName = null;
      _qualificationSubOptions = [];
      _degreeStreams = [];
      _degreeNames = [];

      if (selected != null) {
        if (selected == '10th Pass' || selected == '12th Pass') {
          _qualificationSubOptions = [];
          _degreeStreams = [];
        } else if (_qualificationSubOptionsMap.containsKey(selected)) {
          _qualificationSubOptions = _qualificationSubOptionsMap[selected]!;
          _degreeStreams = [];
        } else if (_degreeStreamsMap.containsKey(selected)) {
          _qualificationSubOptions = [];
          _degreeStreams = _degreeStreamsMap[selected]!;
        }
      }
    });
  }

  void _updateDegreeNames() {
    setState(() {
      if (selectedDegreeStream != null &&
          _degreeSubjectsMap.containsKey(selectedDegreeStream)) {
        _degreeNames = _degreeSubjectsMap[selectedDegreeStream]!;
      } else {
        _degreeNames = [];
      }
      selectedDegreeName = null;
    });
  }

  void _loadCountries() {
    _countries = LocationData.getCountries();
    _selectedCountry = 'India';
    _states = LocationData.getStates('India');
    setState(() {});
  }

  void _setupLocationListeners() {
    cityVillageCtrl.addListener(_updateFullLocation);
  }

  void _updateFullLocation() {
    if (_useCurrentLocation) return;
    final cityVillage = cityVillageCtrl.text.trim();
    final district = _selectedDistrict ?? '';
    final state = _selectedState ?? '';
    final country = _selectedCountry ?? 'India';
    final List<String> parts = [];
    if (cityVillage.isNotEmpty) parts.add(cityVillage);
    if (district.isNotEmpty && district != cityVillage) parts.add(district);
    if (state.isNotEmpty) parts.add(state);
    if (country.isNotEmpty && country != 'India') parts.add(country);
    locationCtrl.text = parts.join(', ');
    _geocodedResult = null;
    _geocodingStatus = '';
  }

  void _onCountryChanged(String? country) {
    setState(() {
      _selectedCountry = country ?? 'India';
      _selectedState = null;
      _selectedDistrict = null;
      _states = LocationData.getStates(_selectedCountry!);
      _districts = [];
    });
    _updateFullLocation();
  }

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      if (_selectedCountry != null && _selectedState != null) {
        _districts = LocationData.getDistricts(
          _selectedCountry!,
          _selectedState!,
        );
      } else {
        _districts = [];
      }
    });
    _updateFullLocation();
  }

  void _onDistrictChanged(String? district) {
    setState(() => _selectedDistrict = district);
    _updateFullLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    organizationCtrl.dispose();
    postNameCtrl.dispose();
    cityVillageCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    lastDateCtrl.dispose();
    postDateCtrl.dispose();
    applyWithUsUrlCtrl.dispose();
    websiteUrlCtrl.dispose();
    officialNotificationUrlCtrl.dispose();
    ageCalcDateCtrl.dispose();
    ageRelaxationCtrl.dispose();
    postNameCtrl2.dispose();
    vacancyCtrl.dispose();
    postAgeMinCtrl.dispose();
    postAgeMaxCtrl.dispose();
    otherQualificationCtrl.dispose();
    educationDetailsCtrl.dispose();
    experienceDetailsCtrl.dispose();
    otherLanguagesCtrl.dispose();
    interviewVenueCtrl.dispose();
    interviewDateCtrl.dispose();
    interviewTimeCtrl.dispose();
    interviewLinkCtrl.dispose();
    contactPersonCtrl.dispose();
    contactDesignationCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    importantNotesCtrl.dispose();
    termsAndConditionsCtrl.dispose();
    selectionProcessDetailsCtrl.dispose();
    bondDurationCtrl.dispose();
    bondAmountCtrl.dispose();
    bondTermsCtrl.dispose();
    admitCardDateCtrl.dispose();
    examDateCtrl.dispose();
    resultDateCtrl.dispose();
    officialWebsiteCtrl.dispose();
    helplineNumberCtrl.dispose();
    helplineEmailCtrl.dispose();
    payScaleCtrl.dispose();
    gradePayCtrl.dispose();
    payBandCtrl.dispose();
    minSalaryCtrl.dispose();
    maxSalaryCtrl.dispose();
    applicationStartDateCtrl.dispose();
    applicationEndDateCtrl.dispose();
    notificationNumberCtrl.dispose();
    notificationDateCtrl.dispose();
    examCityCtrl.dispose();
    minHeightCtrl.dispose();
    minHeightFemaleCtrl.dispose();
    minChestCtrl.dispose();
    maxWeightCtrl.dispose();
    physicalRelaxationCtrl.dispose();
    medicalStandardsCtrl.dispose();
    trainingDurationCtrl.dispose();
    trainingStipendCtrl.dispose();
    trainingLocationCtrl.dispose();
    whatsappNumberCtrl.dispose();
    telegramChannelCtrl.dispose();
    categoryNameCtrl.dispose();
    categoryVacancyCtrl.dispose();
    relaxationCategoryCtrl.dispose();
    relaxationYearsCtrl.dispose();
    feeCategoryCtrl.dispose();
    feeAmountCtrl.dispose();
    for (var controller in relaxationControllers.values) {
      controller.dispose();
    }
    for (var controller in feesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickAdvertisement() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && mounted) {
        final file = result.files.first;
        if (file.size > maxFileSizeBytes) {
          final fileSizeMB = (file.size / (1024 * 1024)).toStringAsFixed(1);
          if (mounted) {
            showMessage(
              context,
              "❌ File size ($fileSizeMB MB) exceeds $maxFileSizeMB MB limit.",
              isError: true,
            );
          }
          return;
        }
        setState(() {
          selectedFileName = file.name;
          selectedFileBytes = file.bytes;
          selectedFileMimeType = _getMimeType(file.name);
          hasAdvertisementFile = true;
        });
        if (mounted) {
          showMessage(context, "✅ File selected: ${file.name}", isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
      }
    }
  }

  void _clearAdvertisementFile() {
    setState(() {
      selectedFileName = null;
      selectedFileBytes = null;
      selectedFileMimeType = null;
      hasAdvertisementFile = false;
    });
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  // ==================== MULTIPLE POST METHODS ====================
  int get _totalVacancySum {
    int sum = 0;
    for (var post in multiplePosts) {
      sum += (post['total_posts'] as int);
    }
    return sum;
  }

  int _getTotalCategoryVacancySum(int postIndex) {
    int sum = 0;
    var categories = multiplePosts[postIndex]['category_vacancies'];
    if (categories != null) {
      for (var cat in categories) {
        sum += (cat['vacancy'] as int);
      }
    }
    return sum;
  }

  String _getQualificationDisplayString() {
    if (selectedDegreeName != null && selectedDegreeName!.isNotEmpty) {
      return selectedDegreeName!;
    }
    if (selectedDegreeStream != null && selectedDegreeStream!.isNotEmpty) {
      return selectedDegreeStream!;
    }
    if (selectedQualificationSubOption != null &&
        selectedQualificationSubOption!.isNotEmpty) {
      return selectedQualificationSubOption!;
    }
    if (selectedQualificationFromEducation != null &&
        selectedQualificationFromEducation!.isNotEmpty) {
      return selectedQualificationFromEducation!;
    }
    return 'Any Graduate';
  }

  void _savePost() {
    final postName = postNameCtrl2.text.trim();
    final vacancy = int.tryParse(vacancyCtrl.text.trim());

    if (postName.isEmpty) {
      showMessage(context, "Post name is required", isError: true);
      return;
    }
    if (vacancy == null || vacancy <= 0) {
      showMessage(context, "Valid number of vacancies is required",
          isError: true);
      return;
    }

    final postData = {
      'post_name': postName,
      'total_posts': vacancy,
      'qualification': _getQualificationDisplayString(),
      'qualification_main': selectedQualificationFromEducation ?? '',
      'qualification_sub': selectedQualificationSubOption ?? '',
      'degree_stream': selectedDegreeStream ?? '',
      'degree_name': selectedDegreeName ?? '',
      'other_qualification_details': otherQualificationCtrl.text.trim(),
      'experience_details': experienceDetailsCtrl.text.trim(),
      'age_min': postAgeMinCtrl.text.trim(),
      'age_max': postAgeMaxCtrl.text.trim(),
      'pay_scales': (_isEditingPost && _editingPostIndex != null)
          ? (multiplePosts[_editingPostIndex!]['pay_scales'] ?? [])
          : [],
      'category_vacancies': (_isEditingPost && _editingPostIndex != null)
          ? (multiplePosts[_editingPostIndex!]['category_vacancies'] ?? [])
          : [],
    };

    setState(() {
      if (_isEditingPost && _editingPostIndex != null) {
        multiplePosts[_editingPostIndex!] = postData;
        showMessage(context, "Post updated successfully");
      } else {
        multiplePosts.add(postData);
        showMessage(context, "Post added successfully");
      }
      _isEditingPost = false;
      _editingPostIndex = null;
    });

    postNameCtrl2.clear();
    vacancyCtrl.clear();
    selectedQualificationFromEducation = null;
    selectedQualificationSubOption = null;
    selectedDegreeStream = null;
    selectedDegreeName = null;
    _qualificationSubOptions = [];
    _degreeStreams = [];
    _degreeNames = [];
    postAgeMinCtrl.clear();
    postAgeMaxCtrl.clear();
    otherQualificationCtrl.clear();
    experienceDetailsCtrl.clear();
  }

  void _startEditPost(int index) {
    final post = multiplePosts[index];
    setState(() {
      _isEditingPost = true;
      _editingPostIndex = index;
      postNameCtrl2.text = post['post_name'] ?? '';
      vacancyCtrl.text = (post['total_posts'] ?? 1).toString();
      selectedQualificationFromEducation = post['qualification_main'];
      selectedQualificationSubOption = post['qualification_sub'];
      selectedDegreeStream = post['degree_stream'];
      selectedDegreeName = post['degree_name'];
      otherQualificationCtrl.text = post['other_qualification_details'] ?? '';
      experienceDetailsCtrl.text = post['experience_details'] ?? '';
      _updateQualificationSubOptions();
      if (selectedDegreeStream != null && selectedDegreeStream!.isNotEmpty) {
        _updateDegreeNames();
      }
      postAgeMinCtrl.text = post['age_min'] ?? '';
      postAgeMaxCtrl.text = post['age_max'] ?? '';
    });
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: Text(
          "Are you sure you want to delete \"${multiplePosts[index]['post_name']}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => multiplePosts.removeAt(index));
              Navigator.pop(context);
              showMessage(context, "Post deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _cancelEditPost() {
    setState(() {
      _isEditingPost = false;
      _editingPostIndex = null;
      postNameCtrl2.clear();
      vacancyCtrl.clear();
      selectedQualificationFromEducation = null;
      selectedQualificationSubOption = null;
      selectedDegreeStream = null;
      selectedDegreeName = null;
      _qualificationSubOptions = [];
      _degreeStreams = [];
      _degreeNames = [];
      postAgeMinCtrl.clear();
      postAgeMaxCtrl.clear();
      otherQualificationCtrl.clear();
      experienceDetailsCtrl.clear();
    });
  }

  // ==================== PAY SCALE METHODS ====================
  void _startEditPayScale(int postIndex, int payScaleIndex) {
    final payScale = multiplePosts[postIndex]['pay_scales'][payScaleIndex];
    setState(() {
      _selectedPostForPayScale = postIndex;
      _isEditingPayScale = true;
      _editingPayScaleIndex = payScaleIndex;
      payScaleCtrl.text = payScale['pay_scale'] ?? '';
      gradePayCtrl.text = payScale['grade_pay'] ?? '';
      payBandCtrl.text = payScale['pay_band'] ?? '';
      minSalaryCtrl.text = payScale['min_salary']?.toString() ?? '';
      maxSalaryCtrl.text = payScale['max_salary']?.toString() ?? '';
    });
  }

  void _savePayScaleForPost() {
    if (_selectedPostForPayScale == null) {
      showMessage(context, "Please select a post first", isError: true);
      return;
    }

    final payScale = payScaleCtrl.text.trim();

    if (payScale.isEmpty &&
        gradePayCtrl.text.trim().isEmpty &&
        payBandCtrl.text.trim().isEmpty &&
        minSalaryCtrl.text.trim().isEmpty &&
        maxSalaryCtrl.text.trim().isEmpty) {
      showMessage(context, "No pay scale data entered. Skipping...");
      _cancelPayScaleForm();
      return;
    }

    final payScaleData = {
      'pay_scale': payScale.isEmpty ? null : payScale,
      'grade_pay':
          gradePayCtrl.text.trim().isEmpty ? null : gradePayCtrl.text.trim(),
      'pay_band':
          payBandCtrl.text.trim().isEmpty ? null : payBandCtrl.text.trim(),
      'min_salary': minSalaryCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(minSalaryCtrl.text.trim()),
      'max_salary': maxSalaryCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(maxSalaryCtrl.text.trim()),
    };

    setState(() {
      if (multiplePosts[_selectedPostForPayScale!]['pay_scales'] == null) {
        multiplePosts[_selectedPostForPayScale!]['pay_scales'] = [];
      }
      if (_isEditingPayScale && _editingPayScaleIndex != null) {
        multiplePosts[_selectedPostForPayScale!]['pay_scales']
            [_editingPayScaleIndex!] = payScaleData;
        showMessage(context, "Pay scale updated successfully");
      } else {
        multiplePosts[_selectedPostForPayScale!]['pay_scales']
            .add(payScaleData);
        showMessage(context, "Pay scale added successfully");
      }
    });

    payScaleCtrl.clear();
    gradePayCtrl.clear();
    payBandCtrl.clear();
    minSalaryCtrl.clear();
    maxSalaryCtrl.clear();
    _selectedPostForPayScale = null;
    _isEditingPayScale = false;
    _editingPayScaleIndex = null;
  }

  void _deletePayScaleFromPost(int postIndex, int payScaleIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pay Scale"),
        content: const Text("Are you sure you want to delete this pay scale?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                multiplePosts[postIndex]['pay_scales'].removeAt(payScaleIndex);
              });
              Navigator.pop(context);
              showMessage(context, "Pay scale deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _cancelPayScaleForm() {
    setState(() {
      _selectedPostForPayScale = null;
      _isEditingPayScale = false;
      _editingPayScaleIndex = null;
      payScaleCtrl.clear();
      gradePayCtrl.clear();
      payBandCtrl.clear();
      minSalaryCtrl.clear();
      maxSalaryCtrl.clear();
    });
  }

  // ==================== CATEGORY VACANCY METHODS ====================
  void _saveCategoryForPost() {
    if (_editingCategoryPostIndex == null) {
      showMessage(context, "Please select a post first", isError: true);
      return;
    }
    final name = categoryNameCtrl.text.trim();
    final vacancy = int.tryParse(categoryVacancyCtrl.text.trim());

    if (name.isEmpty) {
      showMessage(context, "Category name is required", isError: true);
      return;
    }
    if (vacancy == null || vacancy <= 0) {
      showMessage(context, "Valid vacancy number is required", isError: true);
      return;
    }

    setState(() {
      if (multiplePosts[_editingCategoryPostIndex!]['category_vacancies'] ==
          null) {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies'] = [];
      }
      if (_isEditingCategory && _editingCategoryIndex != null) {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies']
            [_editingCategoryIndex!] = {'name': name, 'vacancy': vacancy};
        showMessage(context, "Category updated successfully");
      } else {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies'].add({
          'name': name,
          'vacancy': vacancy,
        });
        showMessage(context, "Category added successfully");
      }
      _editingCategoryPostIndex = null;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _startAddCategoryForPost(int postIndex) {
    setState(() {
      _editingCategoryPostIndex = postIndex;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _startEditCategoryForPost(int postIndex, int catIndex) {
    final cat = multiplePosts[postIndex]['category_vacancies'][catIndex];
    setState(() {
      _editingCategoryPostIndex = postIndex;
      _isEditingCategory = true;
      _editingCategoryIndex = catIndex;
      categoryNameCtrl.text = cat['name'];
      categoryVacancyCtrl.text = cat['vacancy'].toString();
    });
  }

  void _cancelCategoryForPostForm() {
    setState(() {
      _editingCategoryPostIndex = null;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _deleteCategoryFromPost(int postIndex, int catIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category"),
        content: Text(
          "Are you sure you want to delete \"${multiplePosts[postIndex]['category_vacancies'][catIndex]['name']}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                multiplePosts[postIndex]['category_vacancies']
                    .removeAt(catIndex);
              });
              Navigator.pop(context);
              showMessage(context, "Category deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ==================== AGE RELAXATION METHODS ====================
  void _saveRelaxation() {
    final category = relaxationCategoryCtrl.text.trim();
    final years = relaxationYearsCtrl.text.trim();

    if (category.isEmpty) {
      showMessage(context, "Please select a category", isError: true);
      return;
    }
    if (years.isEmpty || int.tryParse(years) == null) {
      showMessage(context, "Valid years is required", isError: true);
      return;
    }

    setState(() {
      relaxationValues[category] = years;
      if (relaxationControllers.containsKey(category)) {
        relaxationControllers[category]?.text = years;
      } else {
        relaxationControllers[category] = TextEditingController(text: years);
      }
      relaxationCategoryCtrl.clear();
      relaxationYearsCtrl.clear();
      _isEditingRelaxation = false;
      _editingRelaxationCategory = null;
    });
    showMessage(context, "Age relaxation saved for $category");
  }

  void _startEditRelaxation(String category, String years) {
    setState(() {
      _isEditingRelaxation = true;
      _editingRelaxationCategory = category;
      relaxationCategoryCtrl.text = category;
      relaxationYearsCtrl.text = years;
    });
  }

  void _cancelRelaxationForm() {
    setState(() {
      _isEditingRelaxation = false;
      _editingRelaxationCategory = null;
      relaxationCategoryCtrl.clear();
      relaxationYearsCtrl.clear();
    });
  }

  void _deleteRelaxation(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Age Relaxation"),
        content: Text(
          "Are you sure you want to delete relaxation for $category?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                relaxationValues.remove(category);
                if (relaxationControllers.containsKey(category)) {
                  relaxationControllers[category]?.clear();
                }
              });
              Navigator.pop(context);
              showMessage(context, "Age relaxation deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ==================== APPLICATION FEES METHODS ====================
  void _saveApplicationFee() {
    final category = feeCategoryCtrl.text.trim();
    final amount = feeAmountCtrl.text.trim();

    if (category.isEmpty) {
      showMessage(context, "Category is required", isError: true);
      return;
    }
    if (amount.isEmpty || int.tryParse(amount) == null) {
      showMessage(context, "Valid fee amount is required", isError: true);
      return;
    }

    setState(() {
      feesValues[category] = amount;
      if (feesControllers.containsKey(category)) {
        feesControllers[category]?.text = amount;
      } else {
        feesControllers[category] = TextEditingController(text: amount);
      }
      feeCategoryCtrl.clear();
      feeAmountCtrl.clear();
      _isEditingFee = false;
      _editingFeeCategory = null;
    });
    showMessage(context, "Application fee saved for $category");
  }

  void _startEditFee(String category, String amount) {
    setState(() {
      _isEditingFee = true;
      _editingFeeCategory = category;
      feeCategoryCtrl.text = category;
      feeAmountCtrl.text = amount;
    });
  }

  void _cancelFeeForm() {
    setState(() {
      _isEditingFee = false;
      _editingFeeCategory = null;
      feeCategoryCtrl.clear();
      feeAmountCtrl.clear();
    });
  }

  void _deleteFee(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Application Fee"),
        content: Text(
          "Are you sure you want to delete application fee for $category?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                feesValues.remove(category);
                if (feesControllers.containsKey(category)) {
                  feesControllers[category]?.clear();
                }
              });
              Navigator.pop(context);
              showMessage(context, "Application fee deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ==================== EXAM CITY METHODS ====================
  void _addExamCity() {
    final city = examCityCtrl.text.trim();
    if (city.isEmpty) {
      showMessage(context, "Please enter exam city name", isError: true);
      return;
    }
    setState(() {
      examCities.add(city);
      examCityCtrl.clear();
    });
    showMessage(context, "Exam city added");
  }

  void _deleteExamCity(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Exam City"),
        content: Text(
          "Are you sure you want to delete \"${examCities[index]}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => examCities.removeAt(index));
              Navigator.pop(context);
              showMessage(context, "Exam city deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNotificationCount() async {
    try {
      await NotificationService.getUnreadCount();
    } catch (e) {
      debugPrint("Error refreshing notification count: $e");
    }
  }

  void _toggleCurrentLocation(bool value) async {
    if (value) {
      if (mounted) {
        setState(() {
          _useCurrentLocation = true;
          _locationStatus = "Checking location...";
          _isGettingLocation = true;
        });
      }
      try {
        final token = await SecureStorage.getToken();
        if (token != null) {
          final response = await DioClient.dio.get('/auth/my-location');
          if (mounted && response.data['has_location'] == true) {
            final location = response.data['location'];
            if (mounted) {
              setState(() {
                _locationStatus =
                    "✅ Using: ${location['location_name'] ?? 'Saved location'}";
              });
            }
            cityVillageCtrl.clear();
            locationCtrl.clear();
            if (mounted) {
              setState(() {
                _selectedCountry = 'India';
                _selectedState = null;
                _selectedDistrict = null;
                _geocodedResult = null;
              });
            }
          } else {
            if (mounted) {
              setState(() => _locationStatus = "⚠️ No saved location found.");
            }
          }
        } else {
          if (mounted) {
            setState(() => _locationStatus = "⚠️ Please login again");
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _locationStatus = "⚠️ Could not fetch location");
        }
      } finally {
        if (mounted) {
          setState(() => _isGettingLocation = false);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _useCurrentLocation = false;
          _locationStatus = "";
          _selectedCountry = 'India';
          _states = LocationData.getStates('India');
          _geocodedResult = null;
          _geocodingStatus = '';
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    if (mounted) {
      setState(() {
        _isGeocoding = true;
        _geocodingStatus = 'Searching for coordinates...';
        _geocodedResult = null;
      });
    }
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1&countrycodes=in&addressdetails=1',
        ),
        headers: {'User-Agent': 'RojgarNext/1.0'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final addressData = data[0]['address'] as Map<String, dynamic>?;
          final result = {
            'latitude': lat,
            'longitude': lon,
            'city': addressData?['city'] ??
                addressData?['town'] ??
                addressData?['village'] ??
                cityVillageCtrl.text.trim(),
            'district': addressData?['state_district'] ??
                addressData?['county'] ??
                _selectedDistrict,
            'state': addressData?['state'] ?? _selectedState,
            'country': 'India',
            'source': 'openstreetmap',
          };
          if (mounted) {
            setState(() {
              _geocodingStatus = '✅ Coordinates found!';
              _geocodedResult = result;
            });
          }
          return result;
        }
      }
      if (mounted) {
        setState(() => _geocodingStatus = '❌ Could not find coordinates');
      }
      return null;
    } catch (e) {
      if (mounted) {
        setState(() => _geocodingStatus = '❌ Error finding location');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _findCoordinates() async {
    if (_useCurrentLocation) {
      if (mounted) {
        showMessage(
          context,
          "Cannot find coordinates when using current location",
          isError: true,
        );
      }
      return;
    }
    final locationText = locationCtrl.text.trim();
    if (locationText.isEmpty) {
      if (mounted) {
        showMessage(context, "Please select location first", isError: true);
      }
      return;
    }
    final result = await _geocodeAddress(locationText);
    if (result != null && mounted) {
      showMessage(
        context,
        "✅ Location found! Lat: ${result['latitude'].toStringAsFixed(6)}, Lon: ${result['longitude'].toStringAsFixed(6)}",
      );
    }
  }

  String _getApiEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs';
      case 'superadmin':
        return '/admin/add-job';
      default:
        return '/admin/add-job';
    }
  }

  String _getUploadEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/upload-advertisement';
      case 'superadmin':
        return '/admin/add-job-with-advertisement';
      default:
        return '/admin/add-job-with-advertisement';
    }
  }

  bool _hasAnyNotification() {
    return (hasOfficialNotificationLink &&
            officialNotificationUrlCtrl.text.trim().isNotEmpty) ||
        (hasAdvertisementFile && selectedFileBytes != null);
  }

  // ==================== MAIN ADD JOB METHOD ====================
  Future<void> _addJob() async {
    if (!_hasAnyNotification()) {
      if (mounted) {
        showMessage(
          context,
          "Please provide either Official Notification PDF Link OR upload an Advertisement file",
          isError: true,
        );
      }
      return;
    }

    if (hasAdvertisementFile &&
        selectedFileBytes != null &&
        selectedFileBytes!.length > maxFileSizeBytes) {
      if (mounted) {
        showMessage(context, "❌ File size exceeds limit", isError: true);
      }
      return;
    }

    if (mounted) {
      setState(() => isLoading = true);
    }

    String locationText = _useCurrentLocation ? "" : locationCtrl.text.trim();
    Map<String, dynamic>? coordinates = _geocodedResult;

    final Map<String, dynamic> jobData = {
      "post_date": postDateCtrl.text.isNotEmpty
          ? postDateCtrl.text.trim()
          : _getCurrentDate(),
      "organization": organizationCtrl.text.trim().isEmpty
          ? "Not Specified"
          : organizationCtrl.text.trim(),
      "post_name": postNameCtrl.text.trim().isEmpty
          ? "Job Opportunity"
          : postNameCtrl.text.trim(),
      "location_text": _useCurrentLocation ? "" : locationText,
      "job_type": jobType,
      "job_level": jobLevel,
      "category": category,
      "status": "open",
      "required_qualification": _getQualificationDisplayString(),
      "experience_min_years": 0,
      "required_skills": [],
      "nice_to_have_skills": [],
      "benefits": selectedBenefits,
      "tags": [],
      "use_current_location": _useCurrentLocation,
      "education_details": educationDetailsCtrl.text.trim(),
      "experience_details": experienceDetailsCtrl.text.trim(),
      "is_fresher_eligible": isFresherEligible,
      "is_experienced_eligible": isExperiencedEligible,
      "work_schedule": selectedWorkSchedule,
      "shift": selectedShift,
      "working_days": selectedWorkingDays,
      "languages_required": selectedLanguages,
      "other_languages": otherLanguagesCtrl.text.trim(),
      "interview_venue":
          isInterviewOnline ? null : interviewVenueCtrl.text.trim(),
      "interview_link":
          isInterviewOnline ? interviewLinkCtrl.text.trim() : null,
      "interview_date": interviewDateCtrl.text.trim(),
      "interview_time": interviewTimeCtrl.text.trim(),
      "interview_documents": interviewDocuments,
      "contact_person": contactPersonCtrl.text.trim(),
      "contact_designation": contactDesignationCtrl.text.trim(),
      "contact_email": contactEmailCtrl.text.trim(),
      "contact_phone": contactPhoneCtrl.text.trim(),
      "important_notes": importantNotesCtrl.text.trim(),
      "terms_conditions": termsAndConditionsCtrl.text.trim(),
      "selection_stages": selectionStages,
      "selection_process_details": selectionProcessDetailsCtrl.text.trim(),
      "urgency_level": selectedUrgency,
      "gender_preference": selectedGenderPreference,
      "is_fully_remote": isFullyRemote,
      "is_hybrid": isHybrid,
      "official_website": officialWebsiteCtrl.text.trim(),
      "helpline_number": helplineNumberCtrl.text.trim(),
      "helpline_email": helplineEmailCtrl.text.trim(),
      "whatsapp_number": whatsappNumberCtrl.text.trim(),
      "telegram_channel": telegramChannelCtrl.text.trim(),
      "application_mode": selectedApplicationMode,
      "exam_cities": examCities,
    };

    if (descriptionCtrl.text.trim().isNotEmpty) {
      jobData["description"] = descriptionCtrl.text.trim();
    }
    if (lastDateCtrl.text.isNotEmpty) {
      jobData["last_date"] = lastDateCtrl.text.trim();
    }
    if (websiteUrlCtrl.text.isNotEmpty) {
      jobData["website_url"] = websiteUrlCtrl.text.trim();
    }
    if (ageCalcDateCtrl.text.isNotEmpty) {
      jobData["age_calculation_date"] = ageCalcDateCtrl.text.trim();
    }

    // Age relaxation
    Map<String, dynamic> ageRelaxations = {};
    for (var entry in relaxationValues.entries) {
      if (entry.value.isNotEmpty) {
        final years = int.tryParse(entry.value);
        if (years != null && years > 0) {
          ageRelaxations[entry.key.toLowerCase()] = years;
        }
      }
    }
    if (ageRelaxations.isNotEmpty) {
      jobData["age_relaxation_by_category"] = ageRelaxations;
    } else if (ageRelaxationCtrl.text.isNotEmpty) {
      jobData["age_relaxation_details"] = ageRelaxationCtrl.text.trim();
    }

    // Application Fees
    if (_hasApplicationFees && feesValues.isNotEmpty) {
      Map<String, dynamic> applicationFees = {};
      for (var entry in feesValues.entries) {
        if (entry.value.isNotEmpty) {
          final amount = int.tryParse(entry.value);
          if (amount != null && amount > 0) {
            applicationFees[entry.key.toLowerCase()] = amount;
          }
        }
      }
      if (applicationFees.isNotEmpty) {
        jobData["application_fees"] = applicationFees;
        jobData["has_application_fees"] = true;
      }
    }

    // Multiple Posts
    if (_showMultiplePosts && multiplePosts.isNotEmpty) {
      List<Map<String, dynamic>> processedPosts = [];
      for (var post in multiplePosts) {
        Map<String, dynamic> processedPost = {
          'post_name': post['post_name'],
          'total_posts': post['total_posts'],
          'qualification': post['qualification'],
          'qualification_main': post['qualification_main'],
          'qualification_sub': post['qualification_sub'],
          'degree_stream': post['degree_stream'],
          'degree_name': post['degree_name'],
          'other_qualification_details':
              post['other_qualification_details'] ?? '',
          'experience_details': post['experience_details'] ?? '',
        };
        if (post['age_min']?.isNotEmpty == true) {
          processedPost['age_min'] = int.tryParse(post['age_min']);
        }
        if (post['age_max']?.isNotEmpty == true) {
          processedPost['age_max'] = int.tryParse(post['age_max']);
        }
        if (post['pay_scales'] != null &&
            (post['pay_scales'] as List).isNotEmpty) {
          processedPost['pay_scales'] = post['pay_scales'];
        }
        if (post['category_vacancies'] != null &&
            (post['category_vacancies'] as List).isNotEmpty) {
          final Map<String, dynamic> postReservation = {};
          for (var cat in post['category_vacancies']) {
            postReservation[cat['name'].toLowerCase().replaceAll('/', '_')] =
                cat['vacancy'];
          }
          if (postReservation.isNotEmpty) {
            processedPost['reservation_vacancy'] = postReservation;
          }
        }
        processedPosts.add(processedPost);
      }
      jobData["multiple_posts"] = processedPosts;
      jobData["total_posts"] = _totalVacancySum;
    }

    // Application Dates
    if (applicationStartDateCtrl.text.isNotEmpty) {
      jobData["application_start_date"] = applicationStartDateCtrl.text.trim();
    }
    if (applicationEndDateCtrl.text.isNotEmpty) {
      jobData["application_end_date"] = applicationEndDateCtrl.text.trim();
    }

    // Official Details
    if (notificationNumberCtrl.text.isNotEmpty) {
      jobData["notification_number"] = notificationNumberCtrl.text.trim();
    }
    if (notificationDateCtrl.text.isNotEmpty) {
      jobData["notification_date"] = notificationDateCtrl.text.trim();
    }

    // Physical Eligibility
    if (_hasPhysicalRequirement) {
      final Map<String, dynamic> physical = {};
      if (minHeightCtrl.text.isNotEmpty) {
        physical["min_height_cm"] = minHeightCtrl.text.trim();
      }
      if (minHeightFemaleCtrl.text.isNotEmpty) {
        physical["min_height_female_cm"] = minHeightFemaleCtrl.text.trim();
      }
      if (minChestCtrl.text.isNotEmpty) {
        physical["min_chest_cm"] = minChestCtrl.text.trim();
      }
      if (maxWeightCtrl.text.isNotEmpty) {
        physical["max_weight_kg"] = maxWeightCtrl.text.trim();
      }
      if (physicalRelaxationCtrl.text.isNotEmpty) {
        physical["relaxation"] = physicalRelaxationCtrl.text.trim();
      }
      if (physical.isNotEmpty) {
        jobData["physical_eligibility"] = physical;
      }
    }

    // Medical Standards
    if (_hasMedicalRequirement && medicalStandardsCtrl.text.isNotEmpty) {
      jobData["medical_standards"] = medicalStandardsCtrl.text.trim();
    }

    // Training Details
    if (_hasTraining) {
      final Map<String, dynamic> training = {};
      if (trainingDurationCtrl.text.isNotEmpty) {
        training["duration"] = trainingDurationCtrl.text.trim();
      }
      if (trainingStipendCtrl.text.isNotEmpty) {
        training["stipend"] = int.tryParse(trainingStipendCtrl.text.trim());
      }
      if (trainingLocationCtrl.text.isNotEmpty) {
        training["location"] = trainingLocationCtrl.text.trim();
      }
      if (training.isNotEmpty) {
        jobData["training_details"] = training;
      }
    }

    // Bond
    if (hasBond) {
      jobData["has_bond"] = true;
      if (bondDurationCtrl.text.isNotEmpty) {
        jobData["bond_duration"] = bondDurationCtrl.text.trim();
      }
      if (bondAmountCtrl.text.isNotEmpty) {
        jobData["bond_amount"] = int.tryParse(bondAmountCtrl.text.trim());
      }
      if (bondTermsCtrl.text.isNotEmpty) {
        jobData["bond_terms"] = bondTermsCtrl.text.trim();
      }
    }

    // Important Dates
    if (admitCardDateCtrl.text.isNotEmpty) {
      jobData["admit_card_date"] = admitCardDateCtrl.text.trim();
    }
    if (examDateCtrl.text.isNotEmpty) {
      jobData["exam_date"] = examDateCtrl.text.trim();
    }
    if (resultDateCtrl.text.isNotEmpty) {
      jobData["result_date"] = resultDateCtrl.text.trim();
    }

    // Official Notification
    if (hasOfficialNotificationLink &&
        officialNotificationUrlCtrl.text.trim().isNotEmpty) {
      jobData["official_notification_url"] =
          officialNotificationUrlCtrl.text.trim();
      jobData["has_official_notification"] = true;
    }

    // Location
    if (!_useCurrentLocation && coordinates != null) {
      jobData["job_location"] = {
        "latitude": coordinates['latitude'],
        "longitude": coordinates['longitude'],
        "location_name": locationText,
        "city": coordinates['city'],
        "district": coordinates['district'],
        "state": coordinates['state'],
        "country": coordinates['country'],
        "is_geocoded": true,
        "geocoded_at": DateTime.now().toIso8601String(),
        "source": coordinates['source'],
      };
    }

    // Apply with Us
    if (hasApplyWithUs && applyWithUsUrlCtrl.text.trim().isNotEmpty) {
      jobData["apply_with_us_url"] = applyWithUsUrlCtrl.text.trim();
      jobData["has_apply_with_us"] = true;
    }

    try {
      if (hasAdvertisementFile &&
          selectedFileBytes != null &&
          selectedFileName != null) {
        if (mounted) {
          setState(() => isUploading = true);
        }
        final token = await SecureStorage.getToken();
        if (token == null) {
          throw Exception("No authentication token found");
        }
        final uri = Uri.parse('${ApiConfig.baseUrl}${_getUploadEndpoint()}');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          selectedFileBytes!,
          filename: selectedFileName!,
          contentType: selectedFileMimeType != null
              ? MediaType.parse(selectedFileMimeType!)
              : null,
        );
        request.files.add(multipartFile);
        request.fields['job_data'] = jsonEncode(jobData);
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (mounted && response.statusCode == 200) {
          showMessage(context, "✅ Job added successfully! Notifications sent.");
          await _refreshNotificationCount();
          _clearForm();
          if (mounted && widget.onJobAdded != null) {
            widget.onJobAdded!();
          }
        } else {
          throw Exception("Upload failed: ${response.statusCode}");
        }
      } else {
        await DioClient.dio.post(_getApiEndpoint(), data: jobData);
        if (mounted) {
          showMessage(context, "✅ Job added successfully! Notifications sent.");
        }
        await _refreshNotificationCount();
        _clearForm();
        if (mounted && widget.onJobAdded != null) {
          widget.onJobAdded!();
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          "Failed to add job: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isUploading = false;
        });
      }
    }
  }

  void _clearForm() {
    organizationCtrl.clear();
    postNameCtrl.clear();
    cityVillageCtrl.clear();
    locationCtrl.clear();
    descriptionCtrl.clear();
    lastDateCtrl.clear();
    postDateCtrl.clear();
    applyWithUsUrlCtrl.clear();
    hasApplyWithUs = false;
    websiteUrlCtrl.clear();
    officialNotificationUrlCtrl.clear();
    hasOfficialNotificationLink = false;
    _clearAdvertisementFile();
    ageCalcDateCtrl.clear();
    ageRelaxationCtrl.clear();
    postNameCtrl2.clear();
    vacancyCtrl.clear();
    selectedQualificationFromEducation = null;
    selectedQualificationSubOption = null;
    selectedDegreeStream = null;
    selectedDegreeName = null;
    _qualificationSubOptions = [];
    _degreeStreams = [];
    _degreeNames = [];
    postAgeMinCtrl.clear();
    postAgeMaxCtrl.clear();
    otherQualificationCtrl.clear();
    multiplePosts.clear();
    _showMultiplePosts = false;
    _useCurrentLocation = false;
    _locationStatus = "";
    payScaleCtrl.clear();
    gradePayCtrl.clear();
    payBandCtrl.clear();
    minSalaryCtrl.clear();
    maxSalaryCtrl.clear();
    _selectedPostForPayScale = null;
    applicationStartDateCtrl.clear();
    applicationEndDateCtrl.clear();
    notificationNumberCtrl.clear();
    notificationDateCtrl.clear();
    examCities.clear();
    examCityCtrl.clear();
    _hasPhysicalRequirement = false;
    minHeightCtrl.clear();
    minHeightFemaleCtrl.clear();
    minChestCtrl.clear();
    maxWeightCtrl.clear();
    physicalRelaxationCtrl.clear();
    _hasMedicalRequirement = false;
    medicalStandardsCtrl.clear();
    _hasTraining = false;
    trainingDurationCtrl.clear();
    trainingStipendCtrl.clear();
    trainingLocationCtrl.clear();
    whatsappNumberCtrl.clear();
    telegramChannelCtrl.clear();
    selectedApplicationMode = 'Online';
    _hasAgeRelaxation = false;
    relaxationValues.clear();
    for (var c in relaxationControllers.values) {
      c.clear();
    }
    _hasApplicationFees = false;
    feesValues.clear();
    for (var c in feesControllers.values) {
      c.clear();
    }
    _isEditingFee = false;
    _editingFeeCategory = null;
    feeCategoryCtrl.clear();
    feeAmountCtrl.clear();

    selectedEducation = 'Any Graduate';
    otherQualificationCtrl.clear();
    educationDetailsCtrl.clear();
    experienceDetailsCtrl.clear();
    isFresherEligible = true;
    isExperiencedEligible = true;
    selectedBenefits.clear();
    selectedWorkSchedule = 'Full Time';
    selectedShift = 'Day Shift';
    selectedWorkingDays = 'Monday to Friday';
    selectedLanguages.clear();
    otherLanguagesCtrl.clear();
    interviewVenueCtrl.clear();
    interviewDateCtrl.clear();
    interviewTimeCtrl.clear();
    isInterviewOnline = false;
    interviewLinkCtrl.clear();
    interviewDocuments.clear();
    contactPersonCtrl.clear();
    contactDesignationCtrl.clear();
    contactEmailCtrl.clear();
    contactPhoneCtrl.clear();
    importantNotesCtrl.clear();
    termsAndConditionsCtrl.clear();
    selectionStages.clear();
    selectionProcessDetailsCtrl.clear();
    hasBond = false;
    bondDurationCtrl.clear();
    bondAmountCtrl.clear();
    bondTermsCtrl.clear();
    selectedUrgency = 'Normal';
    selectedGenderPreference = 'Any';
    isFullyRemote = false;
    isHybrid = false;
    admitCardDateCtrl.clear();
    examDateCtrl.clear();
    resultDateCtrl.clear();
    officialWebsiteCtrl.clear();
    helplineNumberCtrl.clear();
    helplineEmailCtrl.clear();
    jobType = 'private';
    jobLevel = 'mid';
    category = 'IT';
    if (mounted) {
      setState(() {
        _selectedCountry = 'India';
        _selectedState = null;
        _selectedDistrict = null;
        _states = LocationData.getStates('India');
        _districts = [];
        _geocodedResult = null;
        _geocodingStatus = '';
      });
    }
  }

  // ==================== TAB NAVIGATION ====================
  void _goToNextTabSafe() {
    final current = _tabController.index;
    if (current < _tabCount - 1) {
      _tabController.animateTo(current + 1);
    } else {
      showMessage(context, "All sections completed! ✅", isError: false);
    }
  }

  void _goToPreviousTabSafe() {
    final current = _tabController.index;
    if (current > 0) {
      _tabController.animateTo(current - 1);
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicTab(),
                      _buildVacancyTab(),
                      _buildAgeFeesTab(),
                      _buildTimelineTab(),
                      _buildWorkTab(),
                      _buildInterviewTab(),
                      _buildNotificationTab(),
                      _buildExtrasTab(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_safeTabIcon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Add New Job - ${widget.adminRole.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_currentTabIndex + 1}/$_tabCount",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabCount, (index) {
            final isSelected = _currentTabIndex == index;
            return GestureDetector(
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF6C63FF).withOpacity(0.35),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[index],
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF3A3A3A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabLabels[index],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: List.generate(_tabCount, (index) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _currentTabIndex >= index
                        ? const Color(0xFF6C63FF)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Prev button
              if (_currentTabIndex > 0)
                IconButton(
                  onPressed: _goToPreviousTabSafe,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Color(0xFF6C63FF),
                  ),
                  tooltip: "Previous",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              if (_currentTabIndex > 0) const SizedBox(width: 8),
              // Publish button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (isLoading || isUploading) ? null : _addJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (isLoading || isUploading)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.publish, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Publish Job",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Next button
              if (_currentTabIndex < _tabCount - 1)
                IconButton(
                  onPressed: _goToNextTabSafe,
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.white,
                  ),
                  tooltip: "Next",
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB CONTENTS ====================

  // ---------- TAB 1: BASIC ----------
  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Organization Information",
                  Icons.business,
                  subtitle: "Basic details about the job",
                ),
                _buildAITextField(
                  organizationCtrl,
                  "Organization / Company Name",
                  prefixIcon: Icons.business,
                  hintText: "e.g., Google, Microsoft, Government of India",
                ),
                _buildAITextField(
                  postNameCtrl,
                  "Job Title / Post Name",
                  prefixIcon: Icons.work,
                  hintText: "e.g., Software Engineer, Clerk, Manager",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Job Classification",
                  Icons.category,
                  subtitle: "Type, level and category",
                ),
                _buildAIDropdown(
                  jobType,
                  jobTypes,
                  "Job Type *",
                  onChanged: (v) => setState(() => jobType = v!),
                ),
                _buildAIDropdown(
                  jobLevel,
                  jobLevels,
                  "Job Level",
                  onChanged: (v) => setState(() => jobLevel = v!),
                ),
                _buildAIDropdown(
                  category,
                  categories,
                  "Category *",
                  onChanged: (v) => setState(() => category = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Location",
                  Icons.location_on,
                  subtitle: "Where is this job located?",
                ),
                _buildLocationContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 2: VACANCY ----------
  Widget _buildVacancyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Vacancy Details",
                  Icons.people,
                  subtitle: "Add multiple posts with individual details",
                ),
                _buildVacancyToggle(),
                if (_showMultiplePosts) _multiplePostsForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 3: AGE & FEES ----------
  Widget _buildAgeFeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Age Limit & Relaxation",
                  Icons.calendar_today,
                  subtitle: "Set age criteria and category-wise relaxations",
                ),
                _buildAgeLimitContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Fees",
                  Icons.currency_rupee,
                  subtitle: "Category-wise application fees",
                ),
                _buildApplicationFeesContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 4: TIMELINE ----------
  Widget _buildTimelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Timeline",
                  Icons.date_range,
                  subtitle: "Important dates for application",
                ),
                _buildApplicationTimelineContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Important Dates",
                  Icons.event,
                  subtitle: "Admit card, exam and result dates",
                ),
                _buildImportantDatesContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Exam Cities",
                  Icons.location_city,
                  subtitle: "Cities where exam will be conducted",
                ),
                _buildExamCitiesContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Official Details",
                  Icons.assignment,
                  subtitle: "Notification number and mode",
                ),
                _buildOfficialDetailsContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 5: WORK ----------
  Widget _buildWorkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Work Details",
                  Icons.work_outline,
                  subtitle: "Schedule, shift and working days",
                ),
                _buildWorkDetailsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Education & Experience",
                  Icons.school,
                  subtitle: "Qualification and experience required",
                ),
                _buildEducationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Benefits & Perks",
                  Icons.card_giftcard,
                  subtitle: "Select benefits offered",
                ),
                _buildBenefitsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Language Requirements",
                  Icons.language,
                  subtitle: "Languages required for this job",
                ),
                _buildLanguageContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 6: INTERVIEW ----------
  Widget _buildInterviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Interview Details",
                  Icons.people_alt,
                  subtitle: "Venue, date and documents required",
                ),
                _buildInterviewContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Selection Process",
                  Icons.timeline,
                  subtitle: "Stages in selection process",
                ),
                _buildSelectionProcessContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Bond / Agreement",
                  Icons.description,
                  subtitle: "Service bond details if any",
                ),
                _buildBondContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Contact Information",
                  Icons.contact_phone,
                  subtitle: "Contact person and helpline details",
                ),
                _buildContactInformationContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 7: NOTIFICATION ----------
  Widget _buildNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Official Notification",
                  Icons.notifications,
                  subtitle: "Provide PDF link or upload file (required)",
                ),
                _buildOfficialNotificationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Options",
                  Icons.link,
                  subtitle: "Apply with Us and website links",
                ),
                _buildApplicationOptionsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Physical & Medical",
                  Icons.fitness_center,
                  subtitle: "Physical eligibility and medical standards",
                ),
                _buildPhysicalMedicalContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- TAB 8: EXTRAS ----------
  Widget _buildExtrasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Training Details",
                  Icons.school,
                  subtitle: "Training duration, stipend and location",
                ),
                _buildTrainingContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Additional Information",
                  Icons.info_outline,
                  subtitle: "Urgency, gender preference and notes",
                ),
                _buildAdditionalInformationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Job Description",
                  Icons.description,
                  subtitle: "Detailed job description",
                ),
                _buildAITextField(
                  descriptionCtrl,
                  "Job Description (Optional)",
                  maxLines: 6,
                  hintText: "Enter job description",
                  prefixIcon: Icons.description,
                ),
                _buildAITextField(
                  importantNotesCtrl,
                  "Important Notes",
                  maxLines: 3,
                  hintText: "Any special instructions for applicants",
                  prefixIcon: Icons.note,
                ),
                _buildAITextField(
                  termsAndConditionsCtrl,
                  "Terms & Conditions",
                  maxLines: 3,
                  hintText: "Any terms and conditions for the job",
                  prefixIcon: Icons.gavel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Social & Communication",
                  Icons.share,
                  subtitle: "WhatsApp and Telegram links",
                ),
                _buildAITextField(
                  whatsappNumberCtrl,
                  "WhatsApp Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.chat,
                ),
                _buildAITextField(
                  telegramChannelCtrl,
                  "Telegram Channel",
                  hintText: "https://t.me/...",
                  prefixIcon: Icons.telegram,
                ),
                _buildAITextField(
                  officialWebsiteCtrl,
                  "Official Website",
                  hintText: "https://example.com",
                  prefixIcon: Icons.public,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTENT BUILDERS (Tab internals) ====================

  Widget _buildLocationContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _useCurrentLocation
                ? Colors.green.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _useCurrentLocation ? Colors.green : Colors.grey.shade300,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              "Use my current location",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              _useCurrentLocation
                  ? "Job will be posted with your saved account location"
                  : "Enter location manually",
              style: const TextStyle(fontSize: 11),
            ),
            value: _useCurrentLocation,
            onChanged: _toggleCurrentLocation,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.shade100,
          ),
        ),
        if (_isGettingLocation)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text("Checking saved location..."),
              ],
            ),
          ),
        if (_locationStatus.isNotEmpty && !_isGettingLocation && mounted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _locationStatus.contains("✅")
                      ? Icons.check_circle
                      : Icons.warning,
                  size: 16,
                  color: _locationStatus.contains("✅")
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _locationStatus.contains("✅")
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!_useCurrentLocation) ...[
          _buildAITextField(
            cityVillageCtrl,
            "City / Village Name",
            hintText: "e.g., Indore, Kukshi, Bhopal",
            prefixIcon: Icons.location_city,
          ),
          _buildAIDropdown(
            _selectedCountry,
            _countries,
            "Country",
            onChanged: _onCountryChanged,
          ),
          _buildAIDropdown(
            _selectedState,
            _states,
            "State",
            onChanged: _onStateChanged,
          ),
          _buildAIDropdown(
            _selectedDistrict,
            _districts,
            "District",
            onChanged: _onDistrictChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeocoding ? null : _findCoordinates,
              icon: _isGeocoding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                _isGeocoding ? "Searching..." : "Find Coordinates Online",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_geocodingStatus.isNotEmpty && mounted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _geocodingStatus.contains('✅')
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _geocodingStatus.contains('✅')
                          ? Icons.check_circle
                          : Icons.info,
                      size: 16,
                      color: _geocodingStatus.contains('✅')
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _geocodingStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: _geocodingStatus.contains('✅')
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.preview, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Location Format Preview:",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationCtrl.text.isEmpty
                            ? "Select location to see preview"
                            : locationCtrl.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVacancyToggle() {
    return Container(
      decoration: BoxDecoration(
        color:
            _showMultiplePosts ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showMultiplePosts ? Colors.green : Colors.grey.shade300,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          "Add Multiple Posts (Post-wise Details)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          _showMultiplePosts
              ? "ON: Add different posts with separate details"
              : "OFF: No posts added",
          style: const TextStyle(fontSize: 11),
        ),
        value: _showMultiplePosts,
        onChanged: (value) {
          setState(() {
            _showMultiplePosts = value;
            if (!value) {
              multiplePosts.clear();
            }
          });
        },
        activeThumbColor: Colors.green,
        activeTrackColor: Colors.green.shade100,
      ),
    );
  }

  Widget _multiplePostsForm() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Add Post-wise Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAITextField(
                      postNameCtrl2,
                      "Post Name *",
                      prefixIcon: Icons.work,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAITextField(
                      vacancyCtrl,
                      "Number of Vacancies *",
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.people,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Qualification Required:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildAIDropdown(
                      selectedQualificationFromEducation,
                      educationLevels,
                      "Education Level",
                      onChanged: (value) {
                        setState(() {
                          selectedQualificationFromEducation = value;
                          selectedQualificationSubOption = null;
                          selectedDegreeStream = null;
                          selectedDegreeName = null;
                          _qualificationSubOptions = [];
                          _degreeStreams = [];
                          _degreeNames = [];
                          _updateQualificationSubOptions();
                        });
                      },
                    ),
                    if (_qualificationSubOptions.isNotEmpty &&
                        selectedQualificationFromEducation != '10th Pass' &&
                        selectedQualificationFromEducation != '12th Pass' &&
                        selectedQualificationFromEducation != 'Any Graduate' &&
                        selectedQualificationFromEducation != 'Any Post Graduate')
                      _buildAIDropdown(
                        selectedQualificationSubOption,
                        _qualificationSubOptions,
                        "Specific Qualification",
                        onChanged: (value) => setState(
                          () => selectedQualificationSubOption = value,
                        ),
                      ),
                    if (_degreeStreams.isNotEmpty)
                      Column(
                        children: [
                          _buildAIDropdown(
                            selectedDegreeStream,
                            _degreeStreams,
                            "Select Degree",
                            onChanged: (value) {
                              setState(() {
                                selectedDegreeStream = value;
                                selectedDegreeName = null;
                                _degreeNames = [];
                                _updateDegreeNames();
                              });
                            },
                          ),
                          if (_degreeNames.isNotEmpty)
                            _buildAIDropdown(
                              selectedDegreeName,
                              _degreeNames,
                              "Branch / Subject",
                              onChanged: (value) =>
                                  setState(() => selectedDegreeName = value),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _buildAITextField(
                      otherQualificationCtrl,
                      "Other Qualification Details (Optional)",
                      maxLines: 2,
                      hintText: "e.g., Any additional certification or training",
                    ),
                    const SizedBox(height: 12),
                    _buildAITextField(
                      experienceDetailsCtrl,
                      "Experience Details (if any)",
                      maxLines: 2,
                      hintText: "e.g., Minimum 2 years experience required",
                      prefixIcon: Icons.work_history,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAITextField(
                      postAgeMinCtrl,
                      "Min Age (Optional)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAITextField(
                      postAgeMaxCtrl,
                      "Max Age (Optional)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!_isEditingPost)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePost,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Post"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (_isEditingPost) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePost,
                        icon: const Icon(Icons.save),
                        label: const Text("Update Post"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelEditPost,
                        child: const Text("Cancel"),
                      ),
                    ),
                  ],
                  if (!_isEditingPost) const SizedBox(width: 12),
                  if (!_isEditingPost)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditingPost = false;
                            _editingPostIndex = null;
                            postNameCtrl2.clear();
                            vacancyCtrl.clear();
                            selectedQualificationFromEducation = null;
                            selectedQualificationSubOption = null;
                            selectedDegreeStream = null;
                            selectedDegreeName = null;
                            _qualificationSubOptions = [];
                            _degreeStreams = [];
                            _degreeNames = [];
                            postAgeMinCtrl.clear();
                            postAgeMaxCtrl.clear();
                            otherQualificationCtrl.clear();
                            experienceDetailsCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("New Post"),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (multiplePosts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Added Posts:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Total: $_totalVacancySum posts",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...multiplePosts.asMap().entries.map(
                      (entry) => _buildPostCard(entry.key, entry.value),
                    ),
              ],
            ),
          ),
        ],
        if (multiplePosts.isNotEmpty) _payScaleFormPopup(),
        _categoryFormPopup(),
      ],
    );
  }

  Widget _buildPostCard(int index, Map<String, dynamic> post) {
    final hasPayScales =
        post['pay_scales'] != null && (post['pay_scales'] as List).isNotEmpty;
    final qualificationDisplay = post['qualification'] ?? 'Not specified';
    final otherQualification = post['other_qualification_details'] ?? '';
    final experienceDetails = post['experience_details'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          post['post_name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vacancies: ${post['total_posts']}"),
            Text(
              "Qualification: $qualificationDisplay",
              style: const TextStyle(fontSize: 12),
            ),
            if (otherQualification.isNotEmpty)
              Text(
                "Other: $otherQualification",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (experienceDetails.isNotEmpty)
              Text(
                "Experience: $experienceDetails",
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _startEditPost(index),
              tooltip: "Edit Post",
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deletePost(index),
              tooltip: "Delete Post",
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['age_min'].isNotEmpty == true ||
                    post['age_max'].isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Age Limit: ${post['age_min'] ?? ''} - ${post['age_max'] ?? ''} years",
                    ),
                  ),
                if (experienceDetails.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_history,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Experience: $experienceDetails",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  "Salary & Grade Pay Structure:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (hasPayScales)
                  ...(post['pay_scales'] as List).asMap().entries.map(
                        (psEntry) => _buildPayScaleCard(
                            index, psEntry.key, psEntry.value),
                      ),
                if (!hasPayScales)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No pay scales added yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Category-wise Vacancy:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _hasCategoryVacancy,
                          onChanged: (value) {
                            setState(() {
                              _hasCategoryVacancy = value;
                              if (!value &&
                                  post['category_vacancies'] != null) {
                                post['category_vacancies'] = [];
                              }
                            });
                          },
                          activeThumbColor: Colors.indigo,
                          activeTrackColor: Colors.indigo.shade100,
                        ),
                      ],
                    ),
                    if (_hasCategoryVacancy)
                      ElevatedButton.icon(
                        onPressed: () => _startAddCategoryForPost(index),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add Category"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (_hasCategoryVacancy &&
                    post['category_vacancies'] != null &&
                    (post['category_vacancies'] as List).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Category Vacancies:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${_getTotalCategoryVacancySum(index)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...(post['category_vacancies'] as List).asMap().entries.map(
                        (catEntry) => _buildCategoryCard(
                            index, catEntry.key, catEntry.value),
                      ),
                ] else if (_hasCategoryVacancy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No categories added",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayScaleCard(
    int postIndex,
    int psIndex,
    Map<String, dynamic> payScale,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.currency_rupee,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            payScale['pay_scale']?.toString() ?? 'Not specified',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payScale['grade_pay'] != null &&
                  payScale['grade_pay'].toString().isNotEmpty)
                Text(
                  "Grade Pay: ${payScale['grade_pay']}",
                  style: const TextStyle(fontSize: 12),
                ),
              if (payScale['pay_band'] != null &&
                  payScale['pay_band'].toString().isNotEmpty)
                Text(
                  "Pay Band: ${payScale['pay_band']}",
                  style: const TextStyle(fontSize: 12),
                ),
              if (payScale['min_salary'] != null ||
                  payScale['max_salary'] != null)
                Text(
                  "Salary: ${payScale['min_salary'] != null ? '₹${payScale['min_salary']}' : ''}${payScale['min_salary'] != null && payScale['max_salary'] != null ? ' - ' : ''}${payScale['max_salary'] != null ? '₹${payScale['max_salary']}' : ''}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                onPressed: () => _startEditPayScale(postIndex, psIndex),
                tooltip: "Edit Pay Scale",
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _deletePayScaleFromPost(postIndex, psIndex),
                tooltip: "Delete Pay Scale",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    int postIndex,
    int catIndex,
    Map<String, dynamic> category,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.category, color: Colors.indigo),
        title: Text(category['name']),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${category['vacancy']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _startEditCategoryForPost(postIndex, catIndex),
              tooltip: "Edit Category",
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteCategoryFromPost(postIndex, catIndex),
              tooltip: "Delete Category",
            ),
          ],
        ),
      ),
    );
  }

  Widget _payScaleFormPopup() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _sectionHeader(
          "Add Salary & Grade Pay (Optional)",
          Icons.currency_rupee,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "💡 Pay scale is optional. You can skip this section if not applicable.",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedPostForPayScale,
                hint: const Text("Select Post for Salary Structure"),
                decoration: const InputDecoration(
                  labelText: "Select Post *",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: multiplePosts
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value['post_name']),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPostForPayScale = value;
                    _isEditingPayScale = false;
                    _editingPayScaleIndex = null;
                    payScaleCtrl.clear();
                    gradePayCtrl.clear();
                    payBandCtrl.clear();
                    minSalaryCtrl.clear();
                    maxSalaryCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedPostForPayScale != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEditingPayScale
                              ? "Editing Pay Scale for: ${multiplePosts[_selectedPostForPayScale!]['post_name']}"
                              : "Adding Pay Scale for: ${multiplePosts[_selectedPostForPayScale!]['post_name']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAITextField(
                  payScaleCtrl,
                  "Pay Scale (Optional)",
                  hintText: "e.g., ₹44,900 - ₹1,42,400",
                  prefixIcon: Icons.currency_rupee,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        gradePayCtrl,
                        "Grade Pay (Optional)",
                        hintText: "e.g., ₹4,800",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        payBandCtrl,
                        "Pay Band (Optional)",
                        hintText: "e.g., Level 7",
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minSalaryCtrl,
                        "Min Salary (₹) Optional",
                        keyboardType: TextInputType.number,
                        hintText: "e.g., 500000",
                        prefixIcon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        maxSalaryCtrl,
                        "Max Salary (₹) Optional",
                        keyboardType: TextInputType.number,
                        hintText: "e.g., 1200000",
                        prefixIcon: Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelPayScaleForm,
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savePayScaleForPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isEditingPayScale ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _isEditingPayScale
                              ? "Update Salary"
                              : "Add Salary (Optional)",
                        ),
                      ),
                    ),
                  ],
                ),
                if (multiplePosts[_selectedPostForPayScale!]['pay_scales'] !=
                        null &&
                    (multiplePosts[_selectedPostForPayScale!]['pay_scales']
                            as List)
                        .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "Current Salary Structures for this Post:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...(multiplePosts[_selectedPostForPayScale!]['pay_scales']
                          as List)
                      .asMap()
                      .entries
                      .map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.value['pay_scale'] ??
                                          'Not specified',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _startEditPayScale(
                                          _selectedPostForPayScale!,
                                          entry.key,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deletePayScaleFromPost(
                                          _selectedPostForPayScale!,
                                          entry.key,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (entry.value['grade_pay'] != null &&
                                  entry.value['grade_pay']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  "Grade Pay: ${entry.value['grade_pay']}",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (entry.value['pay_band'] != null &&
                                  entry.value['pay_band'].toString().isNotEmpty)
                                Text(
                                  "Pay Band: ${entry.value['pay_band']}",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (entry.value['min_salary'] != null ||
                                  entry.value['max_salary'] != null)
                                Text(
                                  "Salary: ${entry.value['min_salary'] != null ? '₹${entry.value['min_salary']}' : ''}${entry.value['min_salary'] != null && entry.value['max_salary'] != null ? ' - ' : ''}${entry.value['max_salary'] != null ? '₹${entry.value['max_salary']}' : ''}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryFormPopup() {
    if (_editingCategoryPostIndex != null) {
      return Column(
        children: [
          const SizedBox(height: 16),
          _sectionHeader("Category-wise Vacancy", Icons.people_outline),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isEditingCategory ? Icons.edit : Icons.add,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditingCategory
                          ? "Editing Category"
                          : "Adding Category",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: categoryNameCtrl.text.isEmpty
                            ? null
                            : categoryNameCtrl.text,
                        hint: const Text("Select Category"),
                        decoration: const InputDecoration(
                          labelText: "Category",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: predefinedCategories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          categoryNameCtrl.text = value ?? '';
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: categoryVacancyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Vacancies",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isEditingCategory ? Icons.update : Icons.add,
                        color: Colors.indigo,
                      ),
                      onPressed: _saveCategoryForPost,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _cancelCategoryForPostForm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAgeLimitContent() {
    return Column(
      children: [
        _buildAIDateField(ageCalcDateCtrl, "Age Calculation Date"),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Age Relaxation by Category",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _hasAgeRelaxation,
                    onChanged: (value) =>
                        setState(() => _hasAgeRelaxation = value),
                    activeThumbColor: Colors.orange,
                    activeTrackColor: Colors.orange.shade100,
                  ),
                ],
              ),
              if (_hasAgeRelaxation) ...[
                const SizedBox(height: 12),
                const Text(
                  "Enter relaxation in years for each category:",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditingRelaxation ? Icons.edit : Icons.add,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditingRelaxation
                                ? "Edit Relaxation"
                                : "Add New Relaxation",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditingRelaxation)
                            TextButton(
                              onPressed: _cancelRelaxationForm,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _isEditingRelaxation
                                  ? _editingRelaxationCategory
                                  : null,
                              hint: const Text("Select Category"),
                              decoration: const InputDecoration(
                                labelText: "Category",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: relaxationCategories
                                  .map(
                                    (cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  relaxationCategoryCtrl.text = value ?? '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: relaxationYearsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Years",
                                hintText: "e.g., 3",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveRelaxation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditingRelaxation
                                  ? Colors.orange
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              _isEditingRelaxation ? "Update" : "Add",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (relaxationValues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Category-wise Age Relaxation:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${relaxationValues.length} Categories",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...relaxationValues.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${entry.value} years",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _startEditRelaxation(
                                      entry.key,
                                      entry.value,
                                    ),
                                    tooltip: "Edit Relaxation",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteRelaxation(entry.key),
                                    tooltip: "Delete Relaxation",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (relaxationValues.isEmpty && _hasAgeRelaxation)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.category, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No age relaxations added",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "Use the form above to add relaxations for different categories",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "💡 Age relaxation applies to reserved categories as per government rules.",
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationFeesContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                _hasApplicationFees ? Colors.teal.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasApplicationFees ? Colors.teal : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Enable Category-wise Application Fees",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  _hasApplicationFees
                      ? "ON: Set different fees for different categories"
                      : "OFF: No application fees",
                  style: const TextStyle(fontSize: 11),
                ),
                value: _hasApplicationFees,
                onChanged: (value) {
                  setState(() {
                    _hasApplicationFees = value;
                    if (!value) {
                      feesValues.clear();
                      for (var c in feesControllers.values) {
                        c.clear();
                      }
                    }
                  });
                },
                activeThumbColor: Colors.teal,
                activeTrackColor: Colors.teal.shade100,
              ),
              if (_hasApplicationFees) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditingFee ? Icons.edit : Icons.add,
                            size: 20,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditingFee ? "Edit Fee" : "Add New Fee",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.teal,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditingFee)
                            TextButton(
                              onPressed: _cancelFeeForm,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _isEditingFee
                                  ? _editingFeeCategory
                                  : (feeCategoryCtrl.text.isEmpty
                                      ? null
                                      : feeCategoryCtrl.text),
                              hint: const Text("Select Category"),
                              decoration: const InputDecoration(
                                labelText: "Category",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: predefinedFeeCategories
                                  .map(
                                    (cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  feeCategoryCtrl.text = value ?? '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: feeAmountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Fee (₹)",
                                hintText: "e.g., 500",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveApplicationFee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isEditingFee ? Colors.orange : Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(_isEditingFee ? "Update" : "Add"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (feesValues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payment,
                              size: 18,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Category-wise Application Fees:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${feesValues.length} Categories",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...feesValues.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "₹${entry.value}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _startEditFee(entry.key, entry.value),
                                    tooltip: "Edit Fee",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteFee(entry.key),
                                    tooltip: "Delete Fee",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (feesValues.isEmpty && _hasApplicationFees)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.payment, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No application fees added",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "Use the form above to add fees for different categories",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.teal),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "💡 Set application fees for different categories. Users will see these fees when applying.",
                          style: TextStyle(fontSize: 11, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationTimelineContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(
                applicationStartDateCtrl,
                "Application Start Date",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDateField(
                applicationEndDateCtrl,
                "Application End Date",
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAIDropdown(
          selectedApplicationMode,
          applicationModes,
          "Application Mode",
          onChanged: (v) => setState(() => selectedApplicationMode = v!),
        ),
      ],
    );
  }

  Widget _buildImportantDatesContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(admitCardDateCtrl, "Admit Card Date"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDateField(examDateCtrl, "Exam Date"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(resultDateCtrl, "Result Date"),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildExamCitiesContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAITextField(
                examCityCtrl,
                "Exam City Name",
                hintText: "e.g., Indore, Bhopal, Mumbai",
                prefixIcon: Icons.location_on,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _addExamCity,
              icon: const Icon(Icons.add),
              label: const Text("Add"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        if (examCities.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            "Added Exam Cities:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examCities
                .asMap()
                .entries
                .map(
                  (entry) => Chip(
                    label: Text(entry.value),
                    avatar: const Icon(Icons.location_on, size: 16),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _deleteExamCity(entry.key),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildOfficialDetailsContent() {
    return Column(
      children: [
        _buildAITextField(
          notificationNumberCtrl,
          "Notification Number",
          prefixIcon: Icons.confirmation_number,
        ),
        _buildAIDateField(notificationDateCtrl, "Notification Date"),
      ],
    );
  }

  Widget _buildWorkDetailsContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDropdown(
                selectedWorkSchedule,
                workSchedules,
                "Work Schedule",
                onChanged: (v) => setState(() => selectedWorkSchedule = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDropdown(
                selectedShift,
                shifts,
                "Shift",
                onChanged: (v) => setState(() => selectedShift = v!),
              ),
            ),
          ],
        ),
        _buildAIDropdown(
          selectedWorkingDays,
          workingDays,
          "Working Days",
          onChanged: (v) => setState(() => selectedWorkingDays = v!),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleTile(
                title: "Fully Remote",
                value: isFullyRemote,
                onChanged: (v) => setState(() => isFullyRemote = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleTile(
                title: "Hybrid",
                value: isHybrid,
                onChanged: (v) => setState(() => isHybrid = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEducationContent() {
    return Column(
      children: [
        _buildAIDropdown(
          selectedEducation,
          educationLevels,
          "Education Level",
          onChanged: (v) => setState(() => selectedEducation = v!),
        ),
        _buildAITextField(
          educationDetailsCtrl,
          "Education Details",
          maxLines: 3,
          hintText: "Details about required education",
          prefixIcon: Icons.school,
        ),
        _buildAITextField(
          experienceDetailsCtrl,
          "Experience Details",
          maxLines: 3,
          hintText: "e.g., Minimum 2 years experience required",
          prefixIcon: Icons.work_history,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleTile(
                title: "Fresher Eligible",
                value: isFresherEligible,
                onChanged: (v) => setState(() => isFresherEligible = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleTile(
                title: "Experienced Eligible",
                value: isExperiencedEligible,
                onChanged: (v) => setState(() => isExperiencedEligible = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBenefitsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "Select Benefits:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableBenefits.map((benefit) {
              final isSelected = selectedBenefits.contains(benefit);
              return FilterChip(
                label: Text(benefit),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedBenefits.add(benefit);
                    } else {
                      selectedBenefits.remove(benefit);
                    }
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.green.shade200,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "Required Languages:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableLanguages.map((lang) {
              final isSelected = selectedLanguages.contains(lang);
              return FilterChip(
                label: Text(lang),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedLanguages.add(lang);
                    } else {
                      selectedLanguages.remove(lang);
                    }
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.blue.shade200,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildAITextField(
            otherLanguagesCtrl,
            "Other Languages (comma separated)",
            hintText: "e.g., French, German",
            prefixIcon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewContent() {
    return Column(
      children: [
        _buildToggleTile(
          title: "Online Interview",
          value: isInterviewOnline,
          onChanged: (v) => setState(() => isInterviewOnline = v),
        ),
        const SizedBox(height: 12),
        if (isInterviewOnline)
          _buildAITextField(
            interviewLinkCtrl,
            "Interview Link",
            hintText: "https://meet.google.com/...",
            prefixIcon: Icons.link,
          )
        else
          _buildAITextField(
            interviewVenueCtrl,
            "Interview Venue",
            hintText: "Full address with landmark",
            prefixIcon: Icons.location_on,
          ),
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(interviewDateCtrl, "Interview Date"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAITextField(
                interviewTimeCtrl,
                "Interview Time",
                hintText: "e.g., 10:00 AM - 5:00 PM",
                prefixIcon: Icons.access_time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Required Documents for Interview:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: requiredDocuments.map((doc) {
            final isSelected = interviewDocuments.contains(doc);
            return FilterChip(
              label: Text(doc),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    interviewDocuments.add(doc);
                  } else {
                    interviewDocuments.remove(doc);
                  }
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: Colors.orange.shade200,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectionProcessContent() {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableStages.map((stage) {
            final isSelected = selectionStages.contains(stage);
            return FilterChip(
              label: Text(stage),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectionStages.add(stage);
                  } else {
                    selectionStages.remove(stage);
                  }
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: Colors.purple.shade200,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildAITextField(
          selectionProcessDetailsCtrl,
          "Selection Process Details (Optional)",
          maxLines: 3,
          hintText: "Describe the complete selection process...",
          prefixIcon: Icons.description,
        ),
      ],
    );
  }

  Widget _buildBondContent() {
    return Card(
      color: hasBond ? Colors.red.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Service Bond Required",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Is there any service bond or agreement?",
              ),
              value: hasBond,
              onChanged: (newValue) => setState(() => hasBond = newValue),
              activeThumbColor: Colors.red,
              activeTrackColor: Colors.red.shade100,
            ),
            if (hasBond) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                bondDurationCtrl,
                "Bond Duration",
                hintText: "e.g., 2 years",
                prefixIcon: Icons.timer,
              ),
              _buildAITextField(
                bondAmountCtrl,
                "Bond Amount (if any)",
                keyboardType: TextInputType.number,
                hintText: "e.g., 500000",
                prefixIcon: Icons.currency_rupee,
              ),
              _buildAITextField(
                bondTermsCtrl,
                "Bond Terms & Conditions",
                maxLines: 2,
                hintText: "Describe the bond terms...",
                prefixIcon: Icons.description,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactInformationContent() {
    return Column(
      children: [
        _buildAITextField(
          contactPersonCtrl,
          "Contact Person Name",
          prefixIcon: Icons.person,
        ),
        _buildAITextField(
          contactDesignationCtrl,
          "Designation",
          prefixIcon: Icons.badge,
        ),
        _buildAITextField(
          contactEmailCtrl,
          "Contact Email",
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email,
        ),
        _buildAITextField(
          contactPhoneCtrl,
          "Contact Phone Number",
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone,
        ),
        _buildAITextField(
          helplineNumberCtrl,
          "Helpline Number",
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.support_agent,
        ),
        _buildAITextField(
          helplineEmailCtrl,
          "Helpline Email",
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email,
        ),
      ],
    );
  }

  Widget _buildOfficialNotificationContent() {
    return Column(
      children: [
        Card(
          color: hasOfficialNotificationLink
              ? Colors.blue.shade50
              : Colors.grey.shade50,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    "Official Notification PDF Link",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Provide a direct URL link to the official notification PDF",
                  ),
                  value: hasOfficialNotificationLink,
                  onChanged: (value) {
                    setState(() {
                      hasOfficialNotificationLink = value;
                      if (!value) {
                        officialNotificationUrlCtrl.clear();
                      }
                    });
                  },
                  activeThumbColor: Colors.blue,
                  activeTrackColor: Colors.blue.shade100,
                ),
                if (hasOfficialNotificationLink && mounted) ...[
                  const SizedBox(height: 12),
                  _buildAITextField(
                    officialNotificationUrlCtrl,
                    "Official Notification PDF URL",
                    hintText: "https://example.com/notification.pdf",
                    prefixIcon: Icons.picture_as_pdf,
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          color: hasAdvertisementFile
              ? Colors.orange.shade50
              : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    "Upload Advertisement File",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Upload PDF or Image file as advertisement",
                  ),
                  value: hasAdvertisementFile,
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _pickAdvertisement();
                      } else {
                        _clearAdvertisementFile();
                      }
                    });
                  },
                  activeThumbColor: Colors.orange,
                  activeTrackColor: Colors.orange.shade100,
                ),
                if (hasAdvertisementFile &&
                    selectedFileName != null &&
                    mounted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedFileName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${(selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _clearAdvertisementFile,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You can provide EITHER a PDF link OR upload a file. At least one is required.",
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationOptionsContent() {
    return Card(
      color: hasApplyWithUs ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Enable 'Apply with Us' Button",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Redirect users to an external application form",
              ),
              value: hasApplyWithUs,
              onChanged: (value) {
                setState(() {
                  hasApplyWithUs = value;
                  if (!value) {
                    applyWithUsUrlCtrl.clear();
                  }
                });
              },
            ),
            if (hasApplyWithUs && mounted) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                applyWithUsUrlCtrl,
                "Apply With Us URL",
                hintText: "https://example.com/apply",
                prefixIcon: Icons.open_in_browser,
              ),
            ],
            const SizedBox(height: 12),
            _buildAITextField(
              websiteUrlCtrl,
              "Website URL",
              hintText: "https://example.com",
              prefixIcon: Icons.public,
            ),
            _buildAIDateField(lastDateCtrl, "Last Date to Apply"),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalMedicalContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Physical Requirements",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Height, chest, weight requirements (Police/Defense jobs)",
                ),
                value: _hasPhysicalRequirement,
                onChanged: (value) =>
                    setState(() => _hasPhysicalRequirement = value),
                activeThumbColor: Colors.blue,
                activeTrackColor: Colors.blue.shade100,
              ),
              if (_hasPhysicalRequirement) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minHeightCtrl,
                        "Min Height (cm) Male",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        minHeightFemaleCtrl,
                        "Min Height (cm) Female",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minChestCtrl,
                        "Min Chest (cm)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        maxWeightCtrl,
                        "Max Weight (kg)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _buildAITextField(
                  physicalRelaxationCtrl,
                  "Physical Relaxation Details",
                  maxLines: 2,
                  hintText: "Relaxation for reserved categories",
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Medical Standards",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Medical fitness requirements for the job",
                ),
                value: _hasMedicalRequirement,
                onChanged: (value) =>
                    setState(() => _hasMedicalRequirement = value),
                activeThumbColor: Colors.purple,
                activeTrackColor: Colors.purple.shade100,
              ),
              if (_hasMedicalRequirement) ...[
                const SizedBox(height: 12),
                _buildAITextField(
                  medicalStandardsCtrl,
                  "Medical Standards Details",
                  maxLines: 3,
                  hintText: "Describe medical fitness requirements",
                  prefixIcon: Icons.medical_services,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingContent() {
    return Card(
      color: _hasTraining ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Training Details",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Is there any training period for selected candidates?",
              ),
              value: _hasTraining,
              onChanged: (value) => setState(() => _hasTraining = value),
              activeThumbColor: Colors.green,
              activeTrackColor: Colors.green.shade100,
            ),
            if (_hasTraining) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                trainingDurationCtrl,
                "Training Duration",
                hintText: "e.g., 6 months",
                prefixIcon: Icons.timer,
              ),
              _buildAITextField(
                trainingStipendCtrl,
                "Training Stipend (₹)",
                keyboardType: TextInputType.number,
                hintText: "e.g., 15000",
                prefixIcon: Icons.currency_rupee,
              ),
              _buildAITextField(
                trainingLocationCtrl,
                "Training Location",
                hintText: "e.g., Training Academy, Delhi",
                prefixIcon: Icons.location_on,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInformationContent() {
    return Column(
      children: [
        _buildAIDropdown(
          selectedUrgency,
          urgencyLevels,
          "Urgency Level",
          onChanged: (v) => setState(() => selectedUrgency = v!),
        ),
        _buildAIDropdown(
          selectedGenderPreference,
          genderPreferences,
          "Gender Preference",
          onChanged: (v) => setState(() => selectedGenderPreference = v!),
        ),
      ],
    );
  }

  // ==================== REUSABLE WIDGETS ====================
  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    int maxLines = 1,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            hintText: hintText ?? (required ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.transparent,
          ),
          validator: (value) =>
              required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIDropdown<T>(
    T? value,
    List<T> items,
    String label, {
    void Function(T?)? onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (value) => required && value == null ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIDateField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          readOnly: true,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.calendar_today,
              color: Colors.grey.shade600,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: Icon(
              Icons.event,
              color: Colors.grey.shade400,
              size: 18,
            ),
          ),
          onTap: () => _selectDate(ctrl),
          validator: (value) =>
              required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          title: Text(title, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          activeColor: const Color(0xFF6C63FF),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      ),
    );
  }
}