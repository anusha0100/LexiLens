import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexilens/bloc/app_events.dart';
import 'package:lexilens/bloc/app_states.dart';
import 'package:lexilens/services/tts_service.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/document_export_service.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final TTSService _ttsService = TTSService();
  final MongoDBService _mongoService = MongoDBService();
  final AuthService _authService = AuthService();

  AppBloc() : super(const AppState()) {
    _initializeTTS();
    _loadUsername();

    // Navigation Events
    on<NavigateToHome>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.home));
    });

    on<NavigateToScan>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.scan));
    });

    on<NavigateToDocs>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.docs));
    });

    on<NavigateToFilter>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.filter));
    });

    on<NavigateToSettings>((event, emit) {
      emit(state.copyWith(currentTab: AppTab.settings));
    });

    // Document Events
    on<LoadDocuments>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          print('Loading documents for user: $userId');
          final mongoDocuments = await _mongoService.getUserDocuments(userId);
          
          final documents = mongoDocuments.map((doc) {
            print('Converting document: ${doc.name}');
            print('Content length: ${doc.content.length}');
            
            return Document(
              id: doc.id ?? '',
              name: doc.name,
              previewPath: 'assets/doc_preview1.png',
              uploadedDate: doc.uploadedDate,
              content: doc.content,
            );
          }).toList();

          print('Loaded ${documents.length} documents');
          emit(state.copyWith(recentDocuments: documents));
        } catch (e) {
          print('Error loading documents: $e');
          _loadMockDocuments(emit);
        }
      } else {
        print('No user ID - loading mock documents');
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
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📖 OPENING DOCUMENT: ${event.documentPath}');
      
      final doc = state.recentDocuments.firstWhere(
        (d) => d.id == event.documentPath,
        orElse: () => Document(
          id: '0',
          name: 'Not found',
          previewPath: '',
          uploadedDate: DateTime.now(),
          content: '',
        ),
      );
      
      print('Document found: ${doc.name}');
      print('Content length: ${doc.content.length}');
      print('First 200 chars: ${doc.content.substring(0, doc.content.length > 200 ? 200 : doc.content.length)}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      emit(state.copyWith(
        currentDocument: doc,
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<DeleteDocument>((event, emit) async {
      if (state.currentDocument?.id == event.documentId) {
        await _ttsService.stop();
      }
      
      final updatedDocs = state.recentDocuments
          .where((doc) => doc.id != event.documentId)
          .toList();
      
      emit(state.copyWith(
        recentDocuments: updatedDocs,
        currentDocument: state.currentDocument?.id == event.documentId 
            ? null 
            : state.currentDocument,
        readingState: state.currentDocument?.id == event.documentId 
            ? ReadingState.idle 
            : state.readingState,
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
            filePath: event.document!.previewPath,
            uploadedDate: event.document!.uploadedDate,
            tags: event.tags ?? [],
          );
          
          final savedDoc = await _mongoService.createDocument(mongoDoc);
          
          if (savedDoc != null) {
            add(LoadDocuments());
          }
        } catch (e) {
          print('Error saving document: $e');
        }
      }
    });

    on<ToggleFavoriteDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          await _mongoService.updateDocument(
            event.documentId,
            {'isFavorite': event.isFavorite},
          );
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
        } catch (e) {
          print('Error loading tags: $e');
        }
      }
    });

    on<CreateDocumentTag>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final tag = DocumentTag(
            tagName: event.tagName,
            userId: userId,
            color: event.color,
            createdAt: DateTime.now(),
          );
          
          await _mongoService.createTag(tag);
          add(LoadDocumentTags());
        } catch (e) {
          print('Error creating tag: $e');
        }
      }
    });

    // TTS Events
    on<StartTextToSpeech>((event, emit) async {
      final text = event.text ?? 
                   state.currentDocument?.content ?? 
                   "No text available to read.";

      // if user has selected a voice override, apply it before speaking
      if (state.selectedVoice != null) {
        await _ttsService.setVoiceByName(state.selectedVoice!);
      }
      
      print('Starting TTS');
      print('Text length: ${text.length}');
      print('First 100 chars: ${text.substring(0, text.length > 100 ? 100 : text.length)}');
      
      if (text.isEmpty || text == "No text available to read.") {
        return;
      }
      
      emit(state.copyWith(
        readingState: ReadingState.playing,
        currentWordIndex: 0,
      ));
      await _ttsService.speak(text, detectedLanguage: event.detectedLanguage);
    });

    on<StopTextToSpeech>((event, emit) async {
      await _ttsService.stop();
      emit(state.copyWith(
        readingState: ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<PauseTextToSpeech>((event, emit) async {
      await _ttsService.pause();
      emit(state.copyWith(readingState: ReadingState.paused));
    });

    on<ResumeTextToSpeech>((event, emit) async {
      await _ttsService.resume();
      emit(state.copyWith(readingState: ReadingState.playing));
    });

    // Voice loading/selection
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

    on<ToggleBookmark>((event, emit) {
      emit(state.copyWith(isBookmarked: !state.isBookmarked));
    });

    on<ToggleFont>((event, emit) {
      emit(state.copyWith(isFontEnabled: !state.isFontEnabled));
    });

    on<ToggleHighlight>((event, emit) {
      emit(state.copyWith(isHighlighted: !state.isHighlighted));
    });

    on<ToggleRuler>((event, emit) async {
      final newState = !state.isRulerEnabled;
      emit(state.copyWith(isRulerEnabled: newState));
      await _saveUserSetting('ruler_enabled', newState);
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
      final clampedOpacity = event.opacity.clamp(0.5, 1.0);
      emit(state.copyWith(overlayOpacity: clampedOpacity));
      await _saveUserSetting('overlay_opacity', clampedOpacity);
    });

    on<UpdateRulerPosition>((event, emit) async {
      emit(state.copyWith(rulerPosition: event.position));
      await _saveUserSetting('ruler_position', event.position);
    });

    on<AdjustZoom>((event, emit) async {
      final clampedZoom = event.zoomLevel.clamp(1.0, 3.0);
      emit(state.copyWith(zoomLevel: clampedZoom));
      await _saveUserSetting('zoom_level', clampedZoom);
    });

    on<ResetZoom>((event, emit) async {
      emit(state.copyWith(zoomLevel: 1.0));
      await _saveUserSetting('zoom_level', 1.0);
    });

    on<UpdateWordIndex>((event, emit) {
      emit(state.copyWith(currentWordIndex: event.index));
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

    on<SaveFilterSettings>((event, emit) async {
      // Already saved individually
    });

    on<LoadUserSettings>((event, emit) async {
      await _loadUserSettings(emit);
    });

    // Document Export & Sharing Events
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
          print('✅ PDF exported successfully');
          emit(state.copyWith(isExporting: false));
        } else {
          throw Exception('Failed to export PDF');
        }
      } catch (e) {
        print('❌ PDF export error: $e');
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
          print('✅ Text file exported successfully');
          emit(state.copyWith(isExporting: false));
        } else {
          throw Exception('Failed to export text');
        }
      } catch (e) {
        print('❌ Text export error: $e');
        emit(state.copyWith(isExporting: false));
      }
    });

    on<ShareDocument>((event, emit) async {
      emit(state.copyWith(isSharing: true));
      try {
        final exportService = DocumentExportService();
        final success = await exportService.shareDocument(
          documentName: event.documentName,
          content: event.content,
          format: event.format,
          detectedLanguage: event.detectedLanguage,
        );

        if (success) {
          print('✅ Document shared successfully');
        } else {
          print('⚠️ Document sharing dismissed or failed');
        }
        emit(state.copyWith(isSharing: false));
      } catch (e) {
        print('❌ Share error: $e');
        emit(state.copyWith(isSharing: false));
      }
    });

    on<ShareDocumentAsText>((event, emit) async {
      emit(state.copyWith(isSharing: true));
      try {
        final exportService = DocumentExportService();
        final success = await exportService.shareText(
          documentName: event.documentName,
          content: event.content,
        );

        if (success) {
          print('✅ Text shared successfully');
        } else {
          print('⚠️ Text sharing dismissed or failed');
        }
        emit(state.copyWith(isSharing: false));
      } catch (e) {
        print('❌ Text share error: $e');
        emit(state.copyWith(isSharing: false));
      }
    });

    on<UploadPDF>((event, emit) {
      // Handle PDF upload
    });
  }

  void _loadMockDocuments(Emitter<AppState> emit) {
    final mockDocuments = [
      Document(
        id: '1',
        name: 'Sample Document',
        previewPath: 'assets/doc_preview1.png',
        uploadedDate: DateTime.now(),
        content: "This is a sample document. You can upload your own PDFs or text files to see your content here.",
      ),
    ];
    emit(state.copyWith(recentDocuments: mockDocuments));
  }

  Future<void> _loadUsername() async {
    try {
      final username = await _authService.getUsername();
      add(LoadUserProfile());
    } catch (e) {
      print('Error loading username: $e');
    }
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
          // Audio settings
          readingSpeed: settings['reading_speed']?.toDouble() ?? 0.5,
          volume: settings['volume']?.toDouble() ?? 1.0,
          pitch: settings['pitch']?.toDouble() ?? 1.0,
          
          // Color settings
          selectedTextColor: settings['text_color']?.toInt() ?? 0,
          selectedBackgroundColor: settings['background_color']?.toInt() ?? 0,
          
          // Font settings
          fontFamily: settings['font_family']?.toString() ?? 'OpenDyslexic',
          fontSize: settings['font_size']?.toDouble() ?? 18.0,
          lineSpacing: settings['line_spacing']?.toDouble() ?? 1.8,
          letterSpacing: settings['letter_spacing']?.toDouble() ?? 0.5,
          useOpenDyslexic: settings['use_opendyslexic'] ?? true,
          
          // Display settings
          overlayOpacity: settings['overlay_opacity']?.toDouble() ?? 0.75,
          isRulerEnabled: settings['ruler_enabled'] ?? false,
          rulerPosition: settings['ruler_position']?.toDouble() ?? 0.5,
          zoomLevel: settings['zoom_level']?.toDouble() ?? 1.0,
          
          // User info
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
    // load voices into state so UI can show them
    add(LoadAvailableVoices());

    _ttsService.onStart = () {
      add(UpdateReadingState(ReadingState.playing));
    };

    _ttsService.onComplete = () {
      add(UpdateReadingState(ReadingState.idle));
      add(UpdateWordIndex(0));
    };

    _ttsService.onWordHighlight = (index) {
      add(UpdateWordIndex(index));
    };
  }

  @override
  Future<void> close() {
    _ttsService.dispose();
    return super.close();
  }
}