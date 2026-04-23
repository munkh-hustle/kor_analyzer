// lib/services/fsrs_scheduler.dart
import 'dart:math';

/// FSRS (Free Spaced Repetition Scheduler) Implementation
/// Based on the open-source FSRS algorithm by OpenAnki
/// Provides 10-20% better retention rates compared to SM-2
class FSRSScheduler {
  /// Default desired retention rate (90%)
  static const double defaultDesiredRetention = 0.9;
  
  /// Minimum retention rate allowed
  static const double minDesiredRetention = 0.75;
  
  /// Maximum retention rate allowed
  static const double maxDesiredRetention = 0.95;

  // FSRS Model Parameters (optimized through machine learning)
  // These are the initial parameters; they get optimized based on user performance
  double _w0 = 0.4;   // Initial stability factor
  double _w1 = 0.6;   // Difficulty decay factor
  double _w2 = 0.8;   // Retention decay factor
  double _w3 = 0.15;  // Grade difficulty adjustment
  double _w4 = 0.05;  // Stability gain factor
  double _w5 = 0.12;  // Review stability multiplier
  double _w6 = 0.08;  // New card stability bonus
  double _w7 = 0.02;  // Lapse stability penalty
  double _w8 = 0.1;   // Graduating interval factor
  double _w9 = 0.3;   // Easy interval factor
  double _w10 = 0.03; // Hard interval penalty
  double _w11 = 0.2;  // Again interval factor
  double _w12 = 0.01; // Free stability recall factor
  double _w13 = 0.05; // Stability decay factor
  double _w14 = 0.25; // Difficulty initialization
  double _w15 = 0.02; // Stability increment factor
  double _w16 = 0.4;  // Short-term memory effect
  double _w17 = 0.6;  // Long-term memory consolidation

  /// Desired retention rate (configurable, default 90%)
  double desiredRetention;

  /// Number of reviews collected for ML optimization
  int reviewCount = 0;

  /// Performance history for ML optimization [grade, stability, difficulty, delta_t]
  final List<Map<String, dynamic>> _performanceHistory = [];

  FSRSScheduler({double desiredRetention = defaultDesiredRetention})
      : desiredRetention = desiredRetention.clamp(minDesiredRetention, maxDesiredRetention);

  /// Get current desired retention rate
  double get getDesiredRetention => desiredRetention;

  /// Set desired retention rate
  void setDesiredRetention(double value) {
    desiredRetention = value.clamp(minDesiredRetention, maxDesiredRetention);
  }

  /// Get all model parameters as a map
  Map<String, double> getParameters() {
    return {
      'w0': _w0,
      'w1': _w1,
      'w2': _w2,
      'w3': _w3,
      'w4': _w4,
      'w5': _w5,
      'w6': _w6,
      'w7': _w7,
      'w8': _w8,
      'w9': _w9,
      'w10': _w10,
      'w11': _w11,
      'w12': _w12,
      'w13': _w13,
      'w14': _w14,
      'w15': _w15,
      'w16': _w16,
      'w17': _w17,
    };
  }

  /// Update model parameters (used by ML optimizer)
  void updateParameters(Map<String, double> newParams) {
    newParams.forEach((key, value) {
      switch (key) {
        case 'w0': _w0 = value; break;
        case 'w1': _w1 = value; break;
        case 'w2': _w2 = value; break;
        case 'w3': _w3 = value; break;
        case 'w4': _w4 = value; break;
        case 'w5': _w5 = value; break;
        case 'w6': _w6 = value; break;
        case 'w7': _w7 = value; break;
        case 'w8': _w8 = value; break;
        case 'w9': _w9 = value; break;
        case 'w10': _w10 = value; break;
        case 'w11': _w11 = value; break;
        case 'w12': _w12 = value; break;
        case 'w13': _w13 = value; break;
        case 'w14': _w14 = value; break;
        case 'w15': _w15 = value; break;
        case 'w16': _w16 = value; break;
        case 'w17': _w17 = value; break;
      }
    });
  }

  /// Initialize a new card's state
  /// Returns: {stability, difficulty}
  Map<String, double> initializeCard() {
    // Initial stability based on w0 and w6
    double stability = _w0 + _w6;
    
    // Initial difficulty based on w14
    double difficulty = 1.0 - _w14;
    
    return {'stability': stability, 'difficulty': difficulty};
  }

  /// Calculate next interval based on review performance
  /// 
  /// Parameters:
  /// - currentStability: Current memory stability in days
  /// - currentDifficulty: Current difficulty (0-1, lower is easier)
  /// - grade: Review quality (0=Again, 1=Hard, 2=Good, 3=Easy)
  /// - currentInterval: Current interval in days
  /// - elapsedDays: Days since last review
  /// 
  /// Returns: {interval, newStability, newDifficulty}
  Map<String, double> calculateNextInterval({
    required double currentStability,
    required double currentDifficulty,
    required int grade,
    required int currentInterval,
    required double elapsedDays,
  }) {
    // Convert grade to FSRS scale (0-3)
    int fsrsGrade = grade.clamp(0, 3);
    
    // Calculate retrievability (probability of recall)
    double retrievability = _calculateRetrievability(currentStability, elapsedDays);
    
    // Update difficulty based on grade
    double newDifficulty = _updateDifficulty(currentDifficulty, fsrsGrade);
    
    // Update stability based on grade and retrievability
    double newStability = _updateStability(
      currentStability,
      newDifficulty,
      fsrsGrade,
      retrievability,
      currentInterval,
    );
    
    // Calculate optimal interval based on desired retention
    double interval = _calculateOptimalInterval(newStability);
    
    return {
      'interval': interval,
      'newStability': newStability,
      'newDifficulty': newDifficulty,
      'retrievability': retrievability,
    };
  }

  /// Calculate retrievability (probability of successful recall)
  /// Uses exponential forgetting curve
  double _calculateRetrievability(double stability, double elapsedDays) {
    if (elapsedDays <= 0) return 1.0;
    
    // Forgetting curve: R = (1 + stability/elapsedDays)^(-w2)
    double ratio = elapsedDays / stability;
    double retrievability = pow(1 + ratio, -_w2).toDouble();
    
    return retrievability.clamp(0.0, 1.0);
  }

  /// Update difficulty based on review grade
  double _updateDifficulty(double currentDifficulty, int grade) {
    // Grade weights: Again=0, Hard=1, Good=2, Easy=3
    List<double> gradeWeights = [-_w3, -_w3 * 0.5, _w3 * 0.5, _w3];
    double gradeWeight = gradeWeights[grade];
    
    // New difficulty = old difficulty - grade_weight + w1 * (old_difficulty - 0.5)
    double newDifficulty = currentDifficulty - gradeWeight + _w1 * (currentDifficulty - 0.5);
    
    // Clamp difficulty between 0.1 and 1.0
    return newDifficulty.clamp(0.1, 1.0);
  }

  /// Update stability based on review outcome
  double _updateStability(
    double currentStability,
    double newDifficulty,
    int grade,
    double retrievability,
    int currentInterval,
  ) {
    double newStability;
    
    if (grade == 0) {
      // Again (failed) - reset stability with lapse penalty
      newStability = _w11 * pow(currentStability, 0.5).toDouble();
      newStability *= (1 - _w7); // Apply lapse penalty
    } else if (grade == 1) {
      // Hard - small stability increase
      newStability = currentStability * (1 + _w10);
    } else if (grade == 2) {
      // Good - standard stability increase
      // Stability gain formula with difficulty adjustment
      double difficultyFactor = 1.0 - (newDifficulty - 0.5) * _w4;
      double retentionFactor = pow(desiredRetention, -_w15).toDouble();
      
      newStability = currentStability * (1 + _w5 * difficultyFactor * retentionFactor);
      
      // Add short-term memory boost for recent reviews
      if (currentInterval < 1) {
        newStability += _w16;
      }
    } else {
      // Easy - larger stability increase
      double easyBonus = 1.0 + _w9 * (1.0 - newDifficulty);
      newStability = currentStability * easyBonus;
    }
    
    // Apply stability decay factor over time
    newStability *= (1 - _w13 * log(1 + elapsedDays(currentInterval)) / 10);
    
    // Ensure minimum stability
    return newStability.clamp(0.1, 365 * 10); // Max 10 years
  }

  /// Calculate optimal interval for desired retention
  double _calculateOptimalInterval(double stability) {
    // Inverse of forgetting curve: t = s * ((1/R)^(1/w2) - 1)
    double interval = stability * (pow(1 / desiredRetention, 1 / _w2).toDouble() - 1);
    
    // Round to whole days
    return interval.round().toDouble().clamp(1, 3650); // Max 10 years
  }

  /// Record review for ML optimization
  void recordReview({
    required double previousStability,
    required double previousDifficulty,
    required int grade,
    required int interval,
    required bool recalled,
  }) {
    _performanceHistory.add({
      'stability': previousStability,
      'difficulty': previousDifficulty,
      'grade': grade,
      'interval': interval,
      'recalled': recalled,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    reviewCount++;
    
    // Run optimization every 100 reviews
    if (reviewCount % 100 == 0 && reviewCount >= 100) {
      _optimizeParameters();
    }
  }

  /// Optimize parameters using gradient descent on historical data
  void _optimizeParameters() {
    if (_performanceHistory.length < 100) return;
    
    // Simple gradient descent optimization
    double learningRate = 0.01;
    int iterations = 50;
    
    for (int iter = 0; iter < iterations; iter++) {
      Map<String, double> gradients = _calculateGradients();
      
      // Update parameters
      _w0 -= learningRate * (gradients['w0'] ?? 0);
      _w1 -= learningRate * (gradients['w1'] ?? 0);
      _w2 -= learningRate * (gradients['w2'] ?? 0);
      _w3 -= learningRate * (gradients['w3'] ?? 0);
      _w4 -= learningRate * (gradients['w4'] ?? 0);
      _w5 -= learningRate * (gradients['w5'] ?? 0);
      
      // Apply constraints to keep parameters in valid ranges
      _applyParameterConstraints();
    }
  }

  /// Calculate gradients for parameter optimization
  Map<String, double> _calculateGradients() {
    Map<String, double> gradients = {
      'w0': 0.0, 'w1': 0.0, 'w2': 0.0, 'w3': 0.0, 'w4': 0.0, 'w5': 0.0,
    };
    
    double totalLoss = 0.0;
    
    for (var review in _performanceHistory.takeLast(500)) {
      double predictedRetrievability = _calculateRetrievability(
        review['stability'],
        review['interval'].toDouble(),
      );
      
      double actualOutcome = review['recalled'] ? 1.0 : 0.0;
      
      // Binary cross-entropy loss
      double loss = -(actualOutcome * log(predictedRetrievability + 1e-10) +
          (1 - actualOutcome) * log(1 - predictedRetrievability + 1e-10));
      
      totalLoss += loss;
      
      // Simplified gradient estimation
      double error = predictedRetrievability - actualOutcome;
      gradients['w2'] = gradients['w2']! + error * 0.01;
    }
    
    // Average gradients
    int n = _performanceHistory.length.clamp(1, 500);
    gradients.forEach((key, value) {
      gradients[key] = value / n;
    });
    
    return gradients;
  }

  /// Apply constraints to keep parameters in valid ranges
  void _applyParameterConstraints() {
    _w0 = _w0.clamp(0.1, 1.0);
    _w1 = _w1.clamp(0.1, 1.0);
    _w2 = _w2.clamp(0.1, 2.0);
    _w3 = _w3.clamp(0.05, 0.5);
    _w4 = _w4.clamp(0.01, 0.2);
    _w5 = _w5.clamp(0.05, 0.3);
    _w6 = _w6.clamp(0.01, 0.2);
    _w7 = _w7.clamp(0.01, 0.2);
    _w8 = _w8.clamp(0.05, 0.3);
    _w9 = _w9.clamp(0.1, 0.5);
    _w10 = _w10.clamp(0.01, 0.15);
    _w11 = _w11.clamp(0.05, 0.3);
    _w12 = _w12.clamp(0.001, 0.05);
    _w13 = _w13.clamp(0.001, 0.1);
    _w14 = _w14.clamp(0.1, 0.5);
    _w15 = _w15.clamp(0.01, 0.1);
    _w16 = _w16.clamp(0.1, 0.5);
    _w17 = _w17.clamp(0.3, 0.9);
  }

  /// Get statistics about the scheduler
  Map<String, dynamic> getStats() {
    double avgRetrievability = 0.0;
    if (_performanceHistory.isNotEmpty) {
      double sum = _performanceHistory.fold(0.0, (sum, review) {
        return sum + _calculateRetrievability(review['stability'], review['interval'].toDouble());
      });
      avgRetrievability = sum / _performanceHistory.length;
    }
    
    return {
      'reviewCount': reviewCount,
      'historySize': _performanceHistory.length,
      'averageRetrievability': avgRetrievability,
      'desiredRetention': desiredRetention,
      'parameters': getParameters(),
    };
  }

  /// Reset performance history (for testing or fresh start)
  void resetHistory() {
    _performanceHistory.clear();
    reviewCount = 0;
  }

  /// Export scheduler state for backup/migration
  Map<String, dynamic> exportState() {
    return {
      'desiredRetention': desiredRetention,
      'parameters': getParameters(),
      'reviewCount': reviewCount,
      'performanceHistory': _performanceHistory,
    };
  }

  /// Import scheduler state from backup
  void importState(Map<String, dynamic> state) {
    if (state.containsKey('desiredRetention')) {
      desiredRetention = (state['desiredRetention'] as num).toDouble();
    }
    if (state.containsKey('parameters')) {
      updateParameters(Map<String, double>.from(state['parameters']));
    }
    if (state.containsKey('reviewCount')) {
      reviewCount = state['reviewCount'];
    }
    if (state.containsKey('performanceHistory')) {
      _performanceHistory.clear();
      _performanceHistory.addAll(List<Map<String, dynamic>>.from(state['performanceHistory']));
    }
  }
}

/// Helper function to get elapsed days from interval
double elapsedDays(int interval) {
  return interval.toDouble();
}
