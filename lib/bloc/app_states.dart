import 'package:equatable/equatable.dart';
import 'package:lexilens/models/document_tag.dart';

enum AppTab { home, scan, docs, filter, settings }
enum ReadingState { idle, playing, paused }

class AppState extends Equatable {
  final AppTab currentTab;
  final List<Document> recentDocuments;
  final Document? currentDocument;
  final ReadingState readingState;
  final bool isSoundEnabled;
  final bool isBookmarked;
  final bool isFontEnabled;
  final bool isHighlighted;
  final double readingSpeed;
  final double volume;
  final double pitch;
  final int currentWordIndex;
  final int selectedTextColor;
  final int selectedBackgroundColor;
  final String userName;
  final List<DocumentTag> availableTags;
  
  // New font and display settings
  final String fontFamily;
  final double fontSize;
  final double lineSpacing;
  final double letterSpacing;
  final bool useOpenDyslexic;
  final double overlayOpacity;
  final bool isRulerEnabled;
  final double rulerPosition;
  final double zoomLevel;
  final List<String> availableVoices;
  final String? selectedVoice;
  final bool isExporting;
  final bool isSharing;
  final bool isDarkMode;

  const AppState({
    this.currentTab = AppTab.home,
    this.recentDocuments = const [],
    this.currentDocument,
    this.readingState = ReadingState.idle,
    this.isSoundEnabled = true,
    this.isBookmarked = false,
    this.isFontEnabled = true,
    this.isHighlighted = false,
    this.readingSpeed = 0.5,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.currentWordIndex = 0,
    this.selectedTextColor = 0,
    this.selectedBackgroundColor = 0,
    this.userName = 'User',
    this.availableTags = const [],
    // Default font settings
    this.fontFamily = 'OpenDyslexic',
    this.fontSize = 18.0,
    this.lineSpacing = 1.8,
    this.letterSpacing = 0.5,
    this.useOpenDyslexic = true,
    this.overlayOpacity = 0.75,
    this.isRulerEnabled = false,
    this.rulerPosition = 0.5,
    this.zoomLevel = 1.0,
    // voice settings
    this.availableVoices = const [],
    this.selectedVoice,
    // export/share settings
    this.isExporting = false,
    this.isSharing = false,
    this.isDarkMode = false,
  });

  @override
  List<Object?> get props => [
    currentTab,
    recentDocuments,
    currentDocument,
    readingState,
    isSoundEnabled,
    isBookmarked,
    isFontEnabled,
    isHighlighted,
    readingSpeed,
    volume,
    pitch,
    currentWordIndex,
    selectedTextColor,
    selectedBackgroundColor,
    userName,
    availableTags,
    fontFamily,
    fontSize,
    lineSpacing,
    letterSpacing,
    useOpenDyslexic,
    overlayOpacity,
    isRulerEnabled,
    rulerPosition,
    zoomLevel,
    availableVoices,
    selectedVoice,
    isExporting,
    isSharing,
    isDarkMode,
  ];

  AppState copyWith({
    AppTab? currentTab,
    List<Document>? recentDocuments,
    Document? currentDocument,
    ReadingState? readingState,
    bool? isSoundEnabled,
    bool? isBookmarked,
    bool? isFontEnabled,
    bool? isHighlighted,
    double? readingSpeed,
    double? volume,
    double? pitch,
    int? currentWordIndex,
    int? selectedTextColor,
    int? selectedBackgroundColor,
    String? userName,
    List<DocumentTag>? availableTags,
    String? fontFamily,
    double? fontSize,
    double? lineSpacing,
    double? letterSpacing,
    bool? useOpenDyslexic,
    double? overlayOpacity,
    bool? isRulerEnabled,
    double? rulerPosition,
    double? zoomLevel,
    List<String>? availableVoices,
    String? selectedVoice,
    bool? isExporting,
    bool? isSharing,
    bool? isDarkMode,
  }) {
    return AppState(
      currentTab: currentTab ?? this.currentTab,
      recentDocuments: recentDocuments ?? this.recentDocuments,
      currentDocument: currentDocument ?? this.currentDocument,
      readingState: readingState ?? this.readingState,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFontEnabled: isFontEnabled ?? this.isFontEnabled,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      readingSpeed: readingSpeed ?? this.readingSpeed,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      selectedBackgroundColor: selectedBackgroundColor ?? this.selectedBackgroundColor,
      userName: userName ?? this.userName,
      availableTags: availableTags ?? this.availableTags,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      useOpenDyslexic: useOpenDyslexic ?? this.useOpenDyslexic,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      isRulerEnabled: isRulerEnabled ?? this.isRulerEnabled,
      rulerPosition: rulerPosition ?? this.rulerPosition,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      availableVoices: availableVoices ?? this.availableVoices,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      isExporting: isExporting ?? this.isExporting,
      isSharing: isSharing ?? this.isSharing,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

class Document {
  final String id;
  final String name;
  final String previewPath;
  final DateTime uploadedDate;
  final String content;
  final bool isFavorite;

  Document({
    required this.id,
    required this.name,
    required this.previewPath,
    required this.uploadedDate,
    this.content = '',
    this.isFavorite = false,
  });
}