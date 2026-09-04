/// Species offered by the Pet creation screen. Values mirror the shared
/// backend's `PetSpecieEnum` (DOG, CAT, WOLF, FOX, BEAR, LION, OWL) — the
/// design prototype offers all seven, but only four have illustrated art
/// checked into this repo (`assets/pets/`). Wolf, bear and lion are left out
/// of the picker until that art exists; adding an asset + enum entry here is
/// enough to bring one back.
enum PetSpecies {
  fox('FOX', 'assets/pets/fox.png'),
  dog('DOG', 'assets/pets/dog.png'),
  cat('CAT', 'assets/pets/cat.png'),
  owl('OWL', 'assets/pets/owl.png');

  const PetSpecies(this.apiValue, this.assetPath);

  /// Value accepted by `POST /api/pets/configure` (`PetSpecieEnum`).
  final String apiValue;
  final String assetPath;

  static PetSpecies? fromApiValue(String? value) {
    if (value == null) return null;
    for (final species in values) {
      if (species.apiValue == value.toUpperCase()) return species;
    }
    return null;
  }
}
