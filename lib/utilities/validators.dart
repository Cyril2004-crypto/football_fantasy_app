class Validators {
  static String? emailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  static String? confirmPasswordValidator(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }

    return null;
  }

  static String? teamNameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Team name is required';
    }

    if (value.length < 3) {
      return 'Team name must be at least 3 characters';
    }

    if (value.length > 20) {
      return 'Team name must be less than 20 characters';
    }

    return null;
  }

  static String? leagueCodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'League code is required';
    }

    if (value.length < 6) {
      return 'League code must be at least 6 characters';
    }

    return null;
  }
}
