DateTime toUtc(DateTime timestamp) {
  return timestamp.isUtc ? timestamp : timestamp.toUtc();
}

