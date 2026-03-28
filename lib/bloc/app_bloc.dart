import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/tts_service.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/document_export_service.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:share_plus/share_plus.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final TTSService _ttsService = TTSService();
  final MongoDBService _mongoService = MongoDBService();
  final AuthService _authService = AuthService();

  AppBloc() : super(const AppState()) {
    _initializeTTS();
    // FIX Bug #10: removed wasted first getUsername() call; just load profile.
    add(LoadUserProfile());

    // Navigation Events
    on<NavigateToHome>((event, emit) => emit(state.copyWith(currentTab: AppTab.home)));
    on<NavigateToScan>((event, emit) => emit(state.copyWith(currentTab: AppTab.scan)));
    on<NavigateToDocs>((event, emit) => emit(state.copyWith(currentTab: AppTab.docs)));
    on<NavigateToFilter>((event, emit) => emit(state.copyWith(currentTab: AppTab.filter)));
    on<NavigateToSettings>((event, emit) => emit(state.copyWith(currentTab: AppTab.settings)));

    // Document Events
    on<LoadDocuments>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final mongoDocuments = await _mongoService.getUserDocuments(userId);
          final documents = mongoDocuments.map((doc) => Document(
            id: doc.id ?? '',
            name: doc.name,
            previewPath: 'assets/l1.png',
            uploadedDate: doc.uploadedDate,
            content: doc.content,
          )).toList();
          emit(state.copyWith(recentDocuments: documents));
        } catch (e) {
          print('Error loading documents: $e');
          _loadMockDocuments(emit);
        }
      } else {
        _loadMockDocuments(emit);
      }
    });

    on<LoadUserProfile>((event, emit) async {
      try {
        final username = await _authService.getUsername();
        emit(state.copyWith(userName: username));
      } catch (e) {
        print('Error loading username: $e');
      }
    });

    on<OpenDocument>((event, emit) async {
      await _ttsService.stop();
      Document? doc = state.recentDocuments.cast<Document?>().firstWhere(
        (d) => d!.id == event.documentPath, orElse: () => null,
      );
      if (doc == null || doc.content.isEmpty) {
        try {
          final mongoDoc = await _mongoService.getDocument(event.documentPath);
          if (mongoDoc != null && mongoDoc.content.isNotEmpty) {
            doc = Document(
              id: mongoDoc.id ?? event.documentPath,
              name: mongoDoc.name,
              previewPath: 'assets/l1.png',
              uploadedDate: mongoDoc.uploadedDate,
              content: mongoDoc.content,
            );
          }
        } catch (e) {
          print('Error fetching document from MongoDB: $e');
        }
      }
      if (doc == null) return;
      emit(state.copyWith(
        currentDocument: doc,
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<DeleteDocument>((event, emit) async {
      if (state.currentDocument?.id == event.documentId) await _ttsService.stop();
      final updatedDocs = state.recentDocuments.where((doc) => doc.id != event.documentId).toList();
      emit(state.copyWith(
        recentDocuments: updatedDocs,
        currentDocument: state.currentDocument?.id == event.documentId ? null : state.currentDocument,
        readingState: state.currentDocument?.id == event.documentId ? ReadingState.idle : state.readingState,
      ));
    });

    on<SaveDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null && event.document != null) {
        try {
          final mongoDoc = DocumentModel(
            userId: userId,
            name: event.document!.name,
            content: event.document!.content,
            filePath: null,
            uploadedDate: event.document!.uploadedDate,
            tags: event.tags ?? [],
          );
          final savedDoc = await _mongoService.createDocument(mongoDoc);
          if (savedDoc != null) add(LoadDocuments());
        } catch (e) {
          print('Error saving document: $e');
        }
      }
    });

    // FIX Bug #11: ToggleFavoriteDocument now updates local state immediately.
    on<ToggleFavoriteDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          await _mongoService.updateDocument(event.documentId, {'isFavorite': event.isFavorite});
          final updatedDocs = state.recentDocuments.map((doc) {
            if (doc.id == event.documentId) {
              return Document(
                id: doc.id, name: doc.name, previewPath: doc.previewPath,
                uploadedDate: doc.uploadedDate, content: doc.content,
                isFavorite: event.isFavorite,
              );
            }
            return doc;
          }).toList();
          emit(state.copyWith(recentDocuments: updatedDocs));
        } catch (e) {
          print('Error toggling favorite: $e');
        }
      }
    });

    // Tag Events
    on<LoadDocumentTags>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final tags = await _mongoService.getUserTags(userId);
          emit(state.copyWith(availableTags: tags));
        } catch (e) { print('Error loading tags: $e'); }
      }
    });

    on<CreateDocumentTag>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final tag = DocumentTag(tagName: event.tagName, userId: userId, color: event.color, createdAt: DateTime.now());
          await _mongoService.createTag(tag);
          add(LoadDocumentTags());
        } catch (e) { print('Error creating tag: $e'); }
      }
    });

    // TTS Events
    on<StartTextToSpeech>((event, emit) async {
      final text = event.text ?? state.currentDocument?.content ?? "No text available to read.";
      if (state.selectedVoice != null) await _ttsService.setVoiceByName(state.selectedVoice!);
      if (text.isEmpty || text == "No text available to read.") return;
      emit(state.copyWith(readingState: ReadingState.playing, currentWordIndex: 0));
      await _ttsService.speak(text, detectedLanguage: event.detectedLanguage);
    });

    on<StopTextToSpeech>((event, emit) async {
      await _ttsService.stop();
      emit(state.copyWith(readingState: ReadingState.idle, currentWordIndex: 0));
    });

    on<PauseTextToSpeech>((event, emit) async {
      await _ttsService.pause();
      emit(state.copyWith(readingState: ReadingState.paused));
    });

    on<ResumeTextToSpeech>((event, emit) async {
      await _ttsService.resume();
      emit(state.copyWith(readingState: ReadingState.playing));
    });

    // FIX Bug #6: missing handler added — TTS callbacks now update UI state.
    on<UpdateReadingState>((event, emit) {
      emit(state.copyWith(readingState: event.state));
    });

    on<UpdateWordIndex>((event, emit) {
      emit(state.copyWith(currentWordIndex: event.index));
    });

    // Voice events
    on<LoadAvailableVoices>((event, emit) async {
      final voices = await _ttsService.getAvailableVoices() ?? [];
      final names = voices.map((v) {
        if (v is Map) return v['name']?.toString() ?? '';
        return v.toString();
      }).where((n) => n.isNotEmpty).toList();
      emit(state.copyWith(availableVoices: names));
    });

    on<SelectVoice>((event, emit) async {
      emit(state.copyWith(selectedVoice: event.voice));
      await _saveUserSetting('selected_voice', event.voice);
    });

    // Control Events
    on<ToggleSound>((event, emit) async {
      final newState = !state.isSoundEnabled;
      emit(state.copyWith(isSoundEnabled: newState));
      if (!newState) {
        await _ttsService.stop();
        emit(state.copyWith(readingState: ReadingState.idle));
      }
    });

    on<ToggleBookmark>((event, emit) => emit(state.copyWith(isBookmarked: !state.isBookmarked)));
    on<ToggleFont>((event, emit) => emit(state.copyWith(isFontEnabled: !state.isFontEnabled)));
    on<ToggleHighlight>((event, emit) => emit(state.copyWith(isHighlighted: !state.isHighlighted)));

    on<ToggleRuler>((event, emit) async {
      final newState = !state.isRulerEnabled;
      emit(state.copyWith(isRulerEnabled: newState));
      await _saveUserSetting('ruler_enabled', newState);
    });

    // Dark mode — persists and propagates immediately to the MaterialApp theme.
    on<ToggleDarkMode>((event, emit) async {
      final newVal = !state.isDarkMode;
      emit(state.copyWith(isDarkMode: newVal));
      await _saveUserSetting('pref_dark_mode', newVal);
    });

    // Audio Adjustment Events
    on<AdjustSpeed>((event, emit) async {
      emit(state.copyWith(readingSpeed: event.speed));
      await _ttsService.setSpeed(event.speed);
      await _saveUserSetting('reading_speed', event.speed);
    });

    on<AdjustVolume>((event, emit) async {
      emit(state.copyWith(volume: event.volume));
      await _ttsService.setVolume(event.volume);
      await _saveUserSetting('volume', event.volume);
    });

    on<AdjustPitch>((event, emit) async {
      emit(state.copyWith(pitch: event.pitch));
      await _ttsService.setPitch(event.pitch);
      await _saveUserSetting('pitch', event.pitch);
    });

    // Font and Display Events
    on<ChangeFontFamily>((event, emit) async {
      emit(state.copyWith(fontFamily: event.fontFamily));
      await _saveUserSetting('font_family', event.fontFamily);
    });

    // FIX Bug #16: unified storage key 'font_size' for both bloc and prefs screen.
    on<AdjustFontSize>((event, emit) async {
      emit(state.copyWith(fontSize: event.fontSize));
      await _saveUserSetting('font_size', event.fontSize);
    });

    on<AdjustLineSpacing>((event, emit) async {
      emit(state.copyWith(lineSpacing: event.lineSpacing));
      await _saveUserSetting('line_spacing', event.lineSpacing);
    });

    on<AdjustLetterSpacing>((event, emit) async {
      emit(state.copyWith(letterSpacing: event.letterSpacing));
      await _saveUserSetting('letter_spacing', event.letterSpacing);
    });

    on<ToggleOpenDyslexic>((event, emit) async {
      final newState = !state.useOpenDyslexic;
      emit(state.copyWith(useOpenDyslexic: newState));
      await _saveUserSetting('use_opendyslexic', newState);
    });

    on<AdjustOverlayOpacity>((event, emit) async {
      final clamped = event.opacity.clamp(0.5, 1.0);
      emit(state.copyWith(overlayOpacity: clamped));
      await _saveUserSetting('overlay_opacity', clamped);
    });

    on<UpdateRulerPosition>((event, emit) async {
      emit(state.copyWith(rulerPosition: event.position));
      await _saveUserSetting('ruler_position', event.position);
    });

    on<AdjustZoom>((event, emit) async {
      final clamped = event.zoomLevel.clamp(1.0, 3.0);
      emit(state.copyWith(zoomLevel: clamped));
      await _saveUserSetting('zoom_level', clamped);
    });

    on<ResetZoom>((event, emit) async {
      emit(state.copyWith(zoomLevel: 1.0));
      await _saveUserSetting('zoom_level', 1.0);
    });

    // Filter Events
    on<ChangeTextColor>((event, emit) async {
      emit(state.copyWith(selectedTextColor: event.colorIndex));
      await _saveUserSetting('text_color', event.colorIndex);
    });

    on<ChangeBackgroundColor>((event, emit) async {
      emit(state.copyWith(selectedBackgroundColor: event.colorIndex));
      await _saveUserSetting('background_color', event.colorIndex);
    });

    on<SaveFilterSettings>((event, emit) async {});

    on<LoadUserSettings>((event, emit) async {
      await _loadUserSettings(emit);
    });

    // FIX Bug #7: Export handlers now share the file so the user can receive it.
    on<ExportDocumentAsPDF>((event, emit) async {
      emit(state.copyWith(isExporting: true));
      try {
        final exportService = DocumentExportService();
        final pdfFile = await exportService.exportAsPDF(
          documentName: event.documentName,
          content: event.content,
          detectedLanguage: event.detectedLanguage,
        );
        if (pdfFile != null) {
          await Share.shareXFiles([XFile(pdfFile.path)], subject: event.documentName);
        } else {
          throw Exception('Failed to export PDF');
        }
      } catch (e) {
        print('❌ PDF export error: $e');
      } finally {
        emit(state.copyWith(isExporting: false));
      }
    });

    on<ExportDocumentAsText>((event, emit) async {
      emit(state.copyWith(isExporting: true));
      try {
        final exportService = DocumentExportService();
        final textFile = await exportService.exportAsText(
          documentName: event.documentName,
          content: event.content,
        );
        if (textFile != null) {
          await Share.shareXFiles([XFile(textFile.path)], subject: event.documentName);
        } else {
          throw Exception('Failed to export text');
        }
      } catch (e) {
        print('❌ Text export error: $e');
      } finally {
        emit(state.copyWith(isExporting: false));
      }
    });

    on<ShareDocument>((event, emit) async {
      emit(state.copyWith(isSharing: true));
      try {
        final exportService = DocumentExportService();
        await exportService.shareDocument(
          documentName: event.documentName,
          content: event.content,
          format: event.format,
          detectedLanguage: event.detectedLanguage,
        );
      } catch (e) {
        print('❌ Share error: $e');
      } finally {
        emit(state.copyWith(isSharing: false));
      }
    });

    on<ShareDocumentAsText>((event, emit) async {
      emit(state.copyWith(isSharing: true));
      try {
        final exportService = DocumentExportService();
        await exportService.shareText(documentName: event.documentName, content: event.content);
      } catch (e) {
        print('❌ Text share error: $e');
      } finally {
        emit(state.copyWith(isSharing: false));
      }
    });

    on<UploadPDF>((event, emit) {});
  }

  void _loadMockDocuments(Emitter<AppState> emit) {
    emit(state.copyWith(recentDocuments: [
      Document(
        id: '1', name: 'Sample Document',
        previewPath: 'assets/doc_preview1.png',
        uploadedDate: DateTime.now(),
        content: "This is a sample document. You can upload your own PDFs or text files to see your content here.",
      ),
    ]));
  }

  Future<void> _saveUserSetting(String key, dynamic value) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        await _mongoService.updateSetting(userId, key, value);
      } catch (e) {
        print('Error saving setting: $e');
      }
    }
  }

  Future<void> _loadUserSettings(Emitter<AppState> emit) async {
    final userId = _authService.getUserId();
    if (userId != null) {
      try {
        final settings = await _mongoService.getAllSettings(userId);
        emit(state.copyWith(
          readingSpeed: settings['reading_speed']?.toDouble() ?? 0.5,
          volume: settings['volume']?.toDouble() ?? 1.0,
          pitch: settings['pitch']?.toDouble() ?? 1.0,
          selectedTextColor: settings['text_color']?.toInt() ?? 0,
          selectedBackgroundColor: settings['background_color']?.toInt() ?? 0,
          fontFamily: settings['font_family']?.toString() ?? 'OpenDyslexic',
          // FIX Bug #16: read 'font_size'; fall back to old 'pref_default_font_size'
          // key so existing saved prefs are not lost on upgrade.
          fontSize: (settings['font_size'] ?? settings['pref_default_font_size'])?.toDouble() ?? 18.0,
          lineSpacing: settings['line_spacing']?.toDouble() ?? 1.8,
          letterSpacing: settings['letter_spacing']?.toDouble() ?? 0.5,
          useOpenDyslexic: settings['use_opendyslexic'] ?? true,
          overlayOpacity: settings['overlay_opacity']?.toDouble() ?? 0.75,
          isRulerEnabled: settings['ruler_enabled'] ?? false,
          rulerPosition: settings['ruler_position']?.toDouble() ?? 0.5,
          zoomLevel: settings['zoom_level']?.toDouble() ?? 1.0,
          // Dark mode persisted under 'pref_dark_mode'.
          isDarkMode: settings['pref_dark_mode'] ?? false,
          userName: settings['user_name']?.toString() ?? await _authService.getUsername(),
          selectedVoice: settings['selected_voice']?.toString(),
        ));
      } catch (e) {
        print('Error loading settings: $e');
      }
    }
  }

  Future<void> _initializeTTS() async {
    await _ttsService.initialize();
    add(LoadAvailableVoices());

    // FIX Bug #6: these callbacks dispatch to handlers that now exist.
    _ttsService.onStart = () => add(UpdateReadingState(ReadingState.playing));
    _ttsService.onComplete = () {
      add(UpdateReadingState(ReadingState.idle));
      add(UpdateWordIndex(0));
    };
    _ttsService.onWordHighlight = (index) => add(UpdateWordIndex(index));
  }

  @override
  Future<void> close() {
    _ttsService.dispose();
    return super.close();
  }
}