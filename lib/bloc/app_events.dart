import 'package:equatable/equatable.dart';
import 'package:lexilens/bloc/app_states.dart';

abstract class AppEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

// Navigation Events
class NavigateToHome extends AppEvent {}
class NavigateToScan extends AppEvent {}
class NavigateToDocs extends AppEvent {}
class NavigateToFilter extends AppEvent {}
class NavigateToSettings extends AppEvent {}

// User Profile Events
class LoadUserProfile extends AppEvent {}

class UpdateUserProfile extends AppEvent {
  final String? name;
  final String? email;
  final String? phone;
  UpdateUserProfile({this.name, this.email, this.phone});
  @override
  List<Object?> get props => [name, email, phone];
}

// Document Events
class LoadDocuments extends AppEvent {}

class OpenDocument extends AppEvent {
  final String documentPath;
  OpenDocument(this.documentPath);
  @override
  List<Object?> get props => [documentPath];
}

class DeleteDocument extends AppEvent {
  final String documentId;
  DeleteDocument(this.documentId);
  @override
  List<Object?> get props => [documentId];
}

class SaveDocument extends AppEvent {
  final Document? document;
  final List<String>? tags;
  SaveDocument({this.document, this.tags});
  @override
  List<Object?> get props => [document, tags];
}

class ToggleFavoriteDocument extends AppEvent {
  final String documentId;
  final bool isFavorite;
  ToggleFavoriteDocument(this.documentId, this.isFavorite);
  @override
  List<Object?> get props => [documentId, isFavorite];
}

// Tag Events
class LoadDocumentTags extends AppEvent {}

class CreateDocumentTag extends AppEvent {
  final String tagName;
  final String color;
  CreateDocumentTag(this.tagName, this.color);
  @override
  List<Object?> get props => [tagName, color];
}

class DeleteDocumentTag extends AppEvent {
  final String tagId;
  DeleteDocumentTag(this.tagId);
  @override
  List<Object?> get props => [tagId];
}

// Reading/TTS Events
class StartTextToSpeech extends AppEvent {
  final String? text;
  final String? detectedLanguage;
  StartTextToSpeech({this.text, this.detectedLanguage});
  @override
  List<Object?> get props => [text, detectedLanguage];
}

class StopTextToSpeech  extends AppEvent {}
class PauseTextToSpeech extends AppEvent {}
class ResumeTextToSpeech extends AppEvent {}

class UpdateReadingState extends AppEvent {
  final ReadingState state;
  UpdateReadingState(this.state);
  @override
  List<Object?> get props => [state];
}

class UpdateWordIndex extends AppEvent {
  final int index;
  UpdateWordIndex(this.index);
  @override
  List<Object?> get props => [index];
}

// Voice events
class LoadAvailableVoices extends AppEvent {}

class SelectVoice extends AppEvent {
  final String voice;
  SelectVoice(this.voice);
  @override
  List<Object?> get props => [voice];
}

// Control Events
class ToggleSound      extends AppEvent {}
class ToggleBookmark   extends AppEvent {}
class ToggleFont       extends AppEvent {}
class ToggleHighlight  extends AppEvent {}
class ToggleRuler      extends AppEvent {}

// Audio Adjustment Events
class AdjustSpeed extends AppEvent {
  final double speed;
  AdjustSpeed(this.speed);
  @override
  List<Object?> get props => [speed];
}

class AdjustVolume extends AppEvent {
  final double volume;
  AdjustVolume(this.volume);
  @override
  List<Object?> get props => [volume];
}

class AdjustPitch extends AppEvent {
  final double pitch;
  AdjustPitch(this.pitch);
  @override
  List<Object?> get props => [pitch];
}

// Font and Display Events
class ChangeFontFamily extends AppEvent {
  final String fontFamily;
  ChangeFontFamily(this.fontFamily);
  @override
  List<Object?> get props => [fontFamily];
}

class AdjustFontSize extends AppEvent {
  final double fontSize;
  AdjustFontSize(this.fontSize);
  @override
  List<Object?> get props => [fontSize];
}

class AdjustLineSpacing extends AppEvent {
  final double lineSpacing;
  AdjustLineSpacing(this.lineSpacing);
  @override
  List<Object?> get props => [lineSpacing];
}

class AdjustLetterSpacing extends AppEvent {
  final double letterSpacing;
  AdjustLetterSpacing(this.letterSpacing);
  @override
  List<Object?> get props => [letterSpacing];
}

class ToggleOpenDyslexic extends AppEvent {}

class AdjustOverlayOpacity extends AppEvent {
  final double opacity;
  AdjustOverlayOpacity(this.opacity);
  @override
  List<Object?> get props => [opacity];
}

class UpdateRulerPosition extends AppEvent {
  final double position;
  UpdateRulerPosition(this.position);
  @override
  List<Object?> get props => [position];
}

class AdjustZoom extends AppEvent {
  final double zoomLevel;
  AdjustZoom(this.zoomLevel);
  @override
  List<Object?> get props => [zoomLevel];
}

class ResetZoom extends AppEvent {}

// Filter Events
class ChangeTextColor extends AppEvent {
  final int colorIndex;
  ChangeTextColor(this.colorIndex);
  @override
  List<Object?> get props => [colorIndex];
}

class ChangeBackgroundColor extends AppEvent {
  final int colorIndex;
  ChangeBackgroundColor(this.colorIndex);
  @override
  List<Object?> get props => [colorIndex];
}

// FIX: TogglePos — flips the enabled state of a single POS label and persists
// the change immediately so it survives navigation and app restarts.
class TogglePos extends AppEvent {
  /// Lowercase POS label, e.g. 'noun', 'verb', 'adjective'.
  final String label;
  TogglePos(this.label);
  @override
  List<Object?> get props => [label];
}

// FIX: SaveFilterSettings now triggers a full backend write of colour + POS.
class SaveFilterSettings extends AppEvent {}

// Settings Events
class LoadUserSettings extends AppEvent {}

class ToggleDarkMode extends AppEvent {}

class UpdateUserSetting extends AppEvent {
  final String key;
  final dynamic value;
  UpdateUserSetting(this.key, this.value);
  @override
  List<Object?> get props => [key, value];
}

// Upload Events
class UploadPDF extends AppEvent {}

// Document Sharing & Export Events
class ExportDocumentAsPDF extends AppEvent {
  final String documentName;
  final String content;
  final String? detectedLanguage;
  ExportDocumentAsPDF({
    required this.documentName,
    required this.content,
    this.detectedLanguage,
  });
  @override
  List<Object?> get props => [documentName, content, detectedLanguage];
}

class ExportDocumentAsText extends AppEvent {
  final String documentName;
  final String content;
  ExportDocumentAsText({required this.documentName, required this.content});
  @override
  List<Object?> get props => [documentName, content];
}

class ShareDocument extends AppEvent {
  final String documentName;
  final String content;
  final String format;
  final String? detectedLanguage;
  ShareDocument({
    required this.documentName,
    required this.content,
    required this.format,
    this.detectedLanguage,
  });
  @override
  List<Object?> get props => [documentName, content, format, detectedLanguage];
}

class ShareDocumentAsText extends AppEvent {
  final String documentName;
  final String content;
  ShareDocumentAsText({required this.documentName, required this.content});
  @override
  List<Object?> get props => [documentName, content];
}