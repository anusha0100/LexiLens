import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class NextPage extends OnboardingEvent {}

class PreviousPage extends OnboardingEvent {}

class CompleteOnboarding extends OnboardingEvent {}

class GoToPage extends OnboardingEvent {
  final int pageIndex;
  GoToPage(this.pageIndex);

  @override
  List<Object> get props => [pageIndex];
}