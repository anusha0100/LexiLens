import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final int totalPages;

  const OnboardingState({
    required this.currentPage,
    required this.totalPages,
  });

  @override
  List<Object> get props => [currentPage, totalPages];

  OnboardingState copyWith({int? currentPage, int? totalPages}) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}