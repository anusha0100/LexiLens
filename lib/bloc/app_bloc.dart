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
  final TTSService     _ttsService   = TTSService();
  final MongoDBService _mongoService = MongoDBService();
  final AuthService    _authService  = AuthService();

  AppBloc() : super(const AppState()) {
    _initializeTTS();
    add(LoadUserProfile());

    // Navigation
    on<NavigateToHome>    ((e, emit) => emit(state.copyWith(currentTab: AppTab.home)));
    on<NavigateToScan>    ((e, emit) => emit(state.copyWith(currentTab: AppTab.scan)));
    on<NavigateToDocs>    ((e, emit) => emit(state.copyWith(currentTab: AppTab.docs)));
    on<NavigateToFilter>  ((e, emit) => emit(state.copyWith(currentTab: AppTab.filter)));
    on<NavigateToSettings>((e, emit) => emit(state.copyWith(currentTab: AppTab.settings)));

    // ── Documents ────────────────────────────────────────────────────────────

    on<LoadDocuments>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null) {
        try {
          final mongoDocuments = await _mongoService.getUserDocuments(userId);
          final documents = mongoDocuments.map((doc) => Document(
            id:           doc.id ?? '',
            name:         doc.name,
            previewPath:  'assets/l1.png',
            uploadedDate: doc.uploadedDate,
            content:      doc.content,
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

      // FIX: First check the in-memory list (fast path).
      Document? doc = state.recentDocuments.cast<Document?>().firstWhere(
        (d) => d!.id == event.documentPath,
        orElse: () => null,
      );

      // FIX: Also accept a doc from memory that has content — don't skip it
      // just because the content is empty according to the local record.
      // If local content IS empty, fetch from MongoDB.
      if (doc == null || doc.content.isEmpty) {
        try {
          final mongoDoc = await _mongoService.getDocument(event.documentPath);
          if (mongoDoc != null && mongoDoc.content.isNotEmpty) {
            doc = Document(
              // FIX: preserve the exact ID from MongoDB so future lookups match.
              id:           mongoDoc.id ?? event.documentPath,
              name:         mongoDoc.name,
              previewPath:  'assets/l1.png',
              uploadedDate: mongoDoc.uploadedDate,
              content:      mongoDoc.content,
            );
            // Update the in-memory list so the doc is available next time.
            final updated = [
              ...state.recentDocuments.where((d) => d.id != doc!.id),
              doc,
            ];
            emit(state.copyWith(recentDocuments: updated));
          }
        } catch (e) {
          print('Error fetching document from MongoDB: $e');
        }
      }

      if (doc == null) return;

      emit(state.copyWith(
        currentDocument:  doc,
        readingState:     ReadingState.idle,
        currentWordIndex: 0,
      ));
    });

    on<DeleteDocument>((event, emit) async {
      if (state.currentDocument?.id == event.documentId) await _ttsService.stop();
      final updatedDocs = state.recentDocuments
          .where((doc) => doc.id != event.documentId)
          .toList();
      emit(state.copyWith(
        recentDocuments: updatedDocs,
        currentDocument:
            state.currentDocument?.id == event.documentId ? null : state.currentDocument,
        readingState:
            state.currentDocument?.id == event.documentId ? ReadingState.idle : state.readingState,
      ));
    });

    on<SaveDocument>((event, emit) async {
      final userId = _authService.getUserId();
      if (userId != null && event.document != null) {
        try {
          final mongoDoc = DocumentModel(
            userId:       userId,
            name:         event.document!.name,
            content:      event.document!.content,
            filePath:     null,
            uploadedDate: event.document!.uploadedDate,
            tags:         event.tags ?? [],
          );
          final savedDoc = await _mongoService.createDocument(mongoDoc);
          if (savedDoc != null) add(LoadDocuments());
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
              event.documentId, {'isFavorite': event.isFavorite});
          final updatedDocs = state.recentDocuments.map((doc) {
            if (doc.id == event.documentId) {
              return Document(
                id:           doc.id,
                name:         doc.name,
                previewPath:  doc.previewPath,
                uploadedDate: doc.uploadedDate,
                content:      doc.content,
                isFavorite:   event.isFavorite,
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

    // ── Tags ─────────────────────────────────────────────────────────────────

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
          final tag = DocumentTag(
              tagName: event.tagName, userId: userId,
              color: event.color, createdAt: DateTime.now());
          await _mongoService.createTag(tag);
          add(LoadDocumentTags());
        } catch (e) { print('Error creating tag: $e'); }
      }
    });

    // ── TTS ───────────────────────────────────────────────────────────────────

    on<StartTextToSpeech>((event, emit) async {
      final text = event.text ?? state.currentDocument?.content ?? '';
      if (text.trim().isEmpty) return;

      if (state.selectedVoice != null) {
        await _ttsService.setVoiceByName(state.selectedVoice!);
      }

      emit(state.copyWith(readingState: ReadingState.playing, currentWordIndex: 0));

      // FIX: Always interrupt when starting new speech so that tapping a word
      // while audio is playing immediately cancels the old utterance and starts
      // the new one, rather than queuing behind it silently.
      await _ttsService.speak(
        text,
        detectedLanguage: event.detectedLanguage,
        interrupt: true,
      );
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

    on<UpdateReadingState>((event, emit) {
      emit(state.copyWith(readingState: event.state));
    });

    on<UpdateWordIndex>((event, emit) {
      emit(state.copyWith(currentWordIndex: event.index));
    });

    // ── Voice ─────────────────────────────────────────────────────────────────

    on<LoadAvailableVoices>((event, emit) async {
      final voices = await _ttsService.getAvailableVoices() ?? [];
      final names  = voices.map((v) {
        if (v is Map) return v['name']?.toString() ?? '';
        return v.toString();
      }).where((n) => n.isNotEmpty).toList();
      emit(state.copyWith(availableVoices: names));
    });

    on<SelectVoice>((event, emit) async {
      emit(state.copyWith(selectedVoice: event.voice));
      await _saveUserSetting('selected_voice', event.voice);
    });

    // ── Controls ──────────────────────────────────────────────────────────────

    on<ToggleSound>((event, emit) async {
      final newEnabled = !state.isSoundEnabled;
      emit(state.copyWith(isSoundEnabled: newEnabled));
      if (!newEnabled) {
        await _ttsService.stop();
        emit(state.copyWith(readingState: ReadingState.idle));
      }
    });

    on<ToggleBookmark>  ((e, emit) => emit(state.copyWith(isBookmarked:  !state.isBookmarked)));
    on<ToggleFont>      ((e, emit) => emit(state.copyWith(isFontEnabled: !state.isFontEnabled)));
    on<ToggleHighlight> ((e, emit) => emit(state.copyWith(isHighlighted: !state.isHighlighted)));

    on<ToggleRuler>((event, emit) async {
      final v = !state.isRulerEnabled;
      emit(state.copyWith(isRulerEnabled: v));
      await _saveUserSetting('ruler_enabled', v);
    });

    on<ToggleDarkMode>((event, emit) async {
      final v = !state.isDarkMode;
      emit(state.copyWith(isDarkMode: v));
      await _saveUserSetting('pref_dark_mode', v);
    });

    // ── Audio ─────────────────────────────────────────────────────────────────

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

    // ── Display ───────────────────────────────────────────────────────────────

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
      final v = !state.useOpenDyslexic;
      emit(state.copyWith(useOpenDyslexic: v));
      await _saveUserSetting('use_opendyslexic', v);
    });

    on<AdjustOverlayOpacity>((event, emit) async {
      final c = event.opacity.clamp(0.5, 1.0);
      emit(state.copyWith(overlayOpacity: c));
      await _saveUserSetting('overlay_opacity', c);
    });

    on<UpdateRulerPosition>((event, emit) async {
      emit(state.copyWith(rulerPosition: event.position));
      await _saveUserSetting('ruler_position', event.position);
    });

    on<AdjustZoom>((event, emit) async {
      final c = event.zoomLevel.clamp(1.0, 3.0);
      emit(state.copyWith(zoomLevel: c));
      await _saveUserSetting('zoom_level', c);
    });

    on<ResetZoom>((event, emit) async {
      emit(state.copyWith(zoomLevel: 1.0));
      await _saveUserSetting('zoom_level', 1.0);
    });

    // ── Filter ────────────────────────────────────────────────────────────────

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

    // ── Export / Share ────────────────────────────────────────────────────────

    on<ExportDocumentAsPDF>((event, emit) async {
      emit(state.copyWith(isExporting: true));
      try {
        final exportService = DocumentExportService();
        final pdfFile = await exportService.exportAsPDF(
          documentName: event.documentName,
          content:      event.content,
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
            documentName: event.documentName, content: event.content);
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
          documentName:     event.documentName,
          content:          event.content,
          format:           event.format,
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
        await exportService.shareText(
            documentName: event.documentName, content: event.content);
      } catch (e) {
        print('❌ Text share error: $e');
      } finally {
        emit(state.copyWith(isSharing: false));
      }
    });

    on<UploadPDF>((event, emit) {});
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _loadMockDocuments(Emitter<AppState> emit) {
    emit(state.copyWith(recentDocuments: [
      Document(
        id:           '1',
        name:         'Sample Document',
        previewPath:  'assets/doc_preview1.png',
        uploadedDate: DateTime.now(),
        content:
            'This is a sample document. You can upload your own PDFs or text files to see your content here.',
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
        final s = await _mongoService.getAllSettings(userId);
        emit(state.copyWith(
          readingSpeed:           s['reading_speed']?.toDouble()          ?? 0.5,
          volume:                 s['volume']?.toDouble()                  ?? 1.0,
          pitch:                  s['pitch']?.toDouble()                   ?? 1.0,
          selectedTextColor:      s['text_color']?.toInt()                 ?? 0,
          selectedBackgroundColor:s['background_color']?.toInt()           ?? 0,
          fontFamily:             s['font_family']?.toString()             ?? 'OpenDyslexic',
          fontSize:               (s['font_size'] ?? s['pref_default_font_size'])?.toDouble() ?? 18.0,
          lineSpacing:            s['line_spacing']?.toDouble()            ?? 1.8,
          letterSpacing:          s['letter_spacing']?.toDouble()          ?? 0.5,
          useOpenDyslexic:        s['use_opendyslexic']                    ?? true,
          overlayOpacity:         s['overlay_opacity']?.toDouble()         ?? 0.75,
          isRulerEnabled:         s['ruler_enabled']                       ?? false,
          rulerPosition:          s['ruler_position']?.toDouble()          ?? 0.5,
          zoomLevel:              s['zoom_level']?.toDouble()              ?? 1.0,
          isDarkMode:             s['pref_dark_mode']                      ?? false,
          userName:               s['user_name']?.toString() ?? await _authService.getUsername(),
          selectedVoice:          s['selected_voice']?.toString(),
        ));
      } catch (e) {
        print('Error loading settings: $e');
      }
    }
  }

  Future<void> _initializeTTS() async {
    await _ttsService.initialize();
    add(LoadAvailableVoices());
    _ttsService.onStart        = () => add(UpdateReadingState(ReadingState.playing));
    _ttsService.onComplete     = () {
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