class ProfileChoice {
  const ProfileChoice(this.value, [String? label]) : label = label ?? value;

  final String value;
  final String label;
}

class DistrictDivision {
  const DistrictDivision(this.name, this.districts);

  final String name;
  final List<ProfileChoice> districts;
}

const profileCountry = 'Bangladesh';
const profileTimezone = 'Asia/Dhaka';

const profileGenders = ['Male', 'Female'];

const profileProfessions = [
  'Student',
  'Job Holder',
  'Job Seeker',
  'Business Owner',
  'Self-Employed',
  'Other',
];

const bangladeshDivisions = [
  DistrictDivision('Dhaka Division', [
    ProfileChoice('Dhaka'),
    ProfileChoice('Faridpur'),
    ProfileChoice('Gazipur'),
    ProfileChoice('Gopalganj'),
    ProfileChoice('Kishoreganj'),
    ProfileChoice('Madaripur'),
    ProfileChoice('Manikganj'),
    ProfileChoice('Munshiganj'),
    ProfileChoice('Narayanganj'),
    ProfileChoice('Narsingdi'),
    ProfileChoice('Rajbari'),
    ProfileChoice('Shariatpur'),
    ProfileChoice('Tangail'),
  ]),
  DistrictDivision('Chattogram Division', [
    ProfileChoice('Bandarban'),
    ProfileChoice('Brahmanbaria'),
    ProfileChoice('Chandpur'),
    ProfileChoice('Chattogram', 'Chattogram (Chittagong)'),
    ProfileChoice("Cox's Bazar"),
    ProfileChoice('Cumilla', 'Cumilla (Comilla)'),
    ProfileChoice('Feni'),
    ProfileChoice('Khagrachhari'),
    ProfileChoice('Lakshmipur'),
    ProfileChoice('Noakhali'),
    ProfileChoice('Rangamati'),
  ]),
  DistrictDivision('Rajshahi Division', [
    ProfileChoice('Bogura', 'Bogura (Bogra)'),
    ProfileChoice('Chapainawabganj'),
    ProfileChoice('Joypurhat'),
    ProfileChoice('Naogaon'),
    ProfileChoice('Natore'),
    ProfileChoice('Pabna'),
    ProfileChoice('Rajshahi'),
    ProfileChoice('Sirajganj'),
  ]),
  DistrictDivision('Khulna Division', [
    ProfileChoice('Bagerhat'),
    ProfileChoice('Chuadanga'),
    ProfileChoice('Jashore', 'Jashore (Jessore)'),
    ProfileChoice('Jhenaidah'),
    ProfileChoice('Khulna'),
    ProfileChoice('Kushtia'),
    ProfileChoice('Magura'),
    ProfileChoice('Meherpur'),
    ProfileChoice('Narail'),
    ProfileChoice('Satkhira'),
  ]),
  DistrictDivision('Rangpur Division', [
    ProfileChoice('Dinajpur'),
    ProfileChoice('Gaibandha'),
    ProfileChoice('Kurigram'),
    ProfileChoice('Lalmonirhat'),
    ProfileChoice('Nilphamari'),
    ProfileChoice('Panchagarh'),
    ProfileChoice('Rangpur'),
    ProfileChoice('Thakurgaon'),
  ]),
  DistrictDivision('Mymensingh Division', [
    ProfileChoice('Jamalpur'),
    ProfileChoice('Mymensingh'),
    ProfileChoice('Netrokona'),
    ProfileChoice('Sherpur'),
  ]),
  DistrictDivision('Sylhet Division', [
    ProfileChoice('Habiganj'),
    ProfileChoice('Moulvibazar'),
    ProfileChoice('Sunamganj'),
    ProfileChoice('Sylhet'),
  ]),
  DistrictDivision('Barishal Division', [
    ProfileChoice('Barguna'),
    ProfileChoice('Barishal', 'Barishal (Barisal)'),
    ProfileChoice('Bhola'),
    ProfileChoice('Jhalokati'),
    ProfileChoice('Patuakhali'),
    ProfileChoice('Pirojpur'),
  ]),
];

const _districtAliases = {
  'Chittagong': 'Chattogram',
  'Comilla': 'Cumilla',
  'Bogra': 'Bogura',
  'Jessore': 'Jashore',
  'Barisal': 'Barishal',
};

String? knownChoice(List<String> choices, Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  for (final choice in choices) {
    if (choice.toLowerCase() == trimmed.toLowerCase()) return choice;
  }
  return null;
}

String? knownDistrict(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  final canonical = _districtAliases[trimmed] ?? trimmed;
  for (final division in bangladeshDivisions) {
    for (final district in division.districts) {
      if (district.value == canonical) return district.value;
    }
  }
  return null;
}

String districtLabel(String value) {
  for (final division in bangladeshDivisions) {
    for (final district in division.districts) {
      if (district.value == value) return district.label;
    }
  }
  return value;
}
