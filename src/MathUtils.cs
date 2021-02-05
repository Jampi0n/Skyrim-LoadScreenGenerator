float ApproximateProbability (TStringList approximationArray) {
    float approx = 1.0;
    for (int i = 0; i < approximationArray.Count () - 1; i += 1) {
        approx *= strtofloat (approximationArray[i]);
    }
    return approx;
}

float Abs (float x) {
    if (x < 0) {
        return -x;
    } else {
        return x;
    }
}

float ProbabilityLoss (float probability, TStringList approximationArray) {
    return Abs (ApproximateProbability (approximationArray) / probability - 1.0);
}

TStringList CreateRandomProbability (float probability, int num_approx) {
    float dividedProb = Trunc (100.0 * Power (probability, 1.0 / num_approx)) / 100.0;

    float bestLoss = -1.0;
    TStringList bestAttempt = nil;
    TStringList prevAttempt;

    TStringList currentAttempt = TStringList.Create ();
    for (int i = 0; i < num_approx; i += 1) {
        currentAttempt.add (floattostr (dividedProb));
    }
    float currentLoss = ProbabilityLoss (probability, currentAttempt);
    if ((currentLoss < bestLoss) || (bestLoss < -0.5)) {
        bestLoss = currentLoss;
        bestAttempt = currentAttempt;
    }

    for (int i = 0; i < num_approx; i += 1) {
        prevAttempt = currentAttempt;
        currentAttempt = TStringList.Create ();
        for (int j = 0; j < num_approx; j += 1) {
            currentAttempt.add (prevAttempt[j]);
        }
        currentAttempt[i] = floattostr (strtofloat (currentAttempt[i]) + 0.01);

        currentLoss = ProbabilityLoss (probability, currentAttempt);
        if (currentLoss < bestLoss) {
            bestLoss = currentLoss;
            bestAttempt = currentAttempt;
        }
    }

    return bestAttempt;
}

int GCD (int a, int b) {
    if (b == 0) {
        return a;
    } else {
        return GCD (b, a % b);
    }
}