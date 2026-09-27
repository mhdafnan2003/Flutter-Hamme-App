import 'package:flutter_test/flutter_test.dart';
import 'package:hamme_app/core/utils/content_filter.dart';

void main() {
  group('ordinary names are never flagged', () {
    // Real names that contain a blocked word inside them (the "Scunthorpe
    // problem"). None of them may ever be rejected.
    const names = [
      'Harshit',
      'Dikshit',
      'Shitij',
      'Kuntal',
      'Arsh',
      'Sukhdeep',
      'Mishti',
      'Fakir',
      'Titus',
      'Butt',
      'Cassandra',
      'Dickson',
      'Sussex',
      'Scunthorpe',
      'Assam',
      'Hancock',
      // A few more classic false positives.
      'Dick Van Dyke',
      'Randi',
      'Anal Mehta',
      'Nazir',
      'Pornchai',
      'Cockburn',
      'Hitchcock',
      'Penistone',
      'Middlesex',
      'Essex',
      'Therapist',
      'Grape',
      'Pedro',
      'Shiitake',
      'Gandhi',
      'Chodankar',
      'Bhosale',
      'Lund',
      'Kutti',
      'Slutsky',
      'Fukuda',
      'Cummings',
      'W Hore',
      'A S S Kumar',
    ];

    for (final name in names) {
      test(name, () {
        expect(ContentFilter.isObjectionable(name), isFalse);
        expect(ContentFilter.isObjectionable(name.toUpperCase()), isFalse);
        expect(
          ContentFilter.validate(name, ContentFilterField.name),
          isNull,
          reason: '"$name" must be accepted as a display name',
        );
      });
    }

    test('as usernames and social handles', () {
      const handles = [
        'harshit',
        'harshit.dikshit',
        'dikshit_07',
        'shitij99',
        'kuntal.sharma',
        'arsh_1',
        'sukhdeep.singh',
        'mishti_',
        'fakir.butt',
        'titus4',
        'cassandra.dickson',
        'sussex_uni',
        'scunthorpe_united',
        'assam2024',
        'hancock__',
        'john_455',
        'user1700000000000',
      ];
      for (final handle in handles) {
        for (final field in [
          ContentFilterField.username,
          ContentFilterField.instagram,
          ContentFilterField.snapchat,
        ]) {
          expect(
            ContentFilter.validate(handle, field),
            isNull,
            reason: '"$handle" must be accepted as a $field',
          );
        }
      }
    });

    test('empty input is not objectionable', () {
      expect(ContentFilter.isObjectionable(null), isFalse);
      expect(ContentFilter.isObjectionable(''), isFalse);
      expect(ContentFilter.isObjectionable('   '), isFalse);
    });
  });

  group('objectionable text is flagged', () {
    const blocked = [
      'fuck',
      'FUCK YOU',
      'fuckboy',
      'f.u.c.k',
      'f u c k',
      'fuuuuck',
      'shit',
      'Sh1t head',
      'bullshit',
      'a55hole',
      'asshole',
      'b1tch',
      'biiitch',
      'son of a bitch',
      'cunt',
      'nigga',
      'n1gger',
      'faggot',
      'whore',
      'slut',
      'rapist',
      'pedo',
      'hitler',
      'pornhub',
      'sex',
      // Hindi / Hinglish
      'madarchod',
      'Behenchod',
      'bhenchod',
      'bhosdike',
      'chutiya',
      'ch00tiya',
      'gandu',
      'harami',
      'haramzada',
      'lawda',
      'randibaaz',
      // Devanagari
      'मादरचोद',
      'बहनचोद',
      'चूतिया',
      'भोसड़ी के',
      'गांडू',
      'रंडी',
    ];

    for (final text in blocked) {
      test(text, () {
        expect(ContentFilter.isObjectionable(text), isTrue);
      });
    }

    test('words glued together in handles', () {
      for (final handle in ['kill_yourself', 'killyourself', 'big.dick']) {
        expect(
          ContentFilter.validate(handle, ContentFilterField.username),
          isNotNull,
          reason: '"$handle" must be rejected as a username',
        );
      }
    });
  });

  group('rejection messages', () {
    test('use field-appropriate wording', () {
      expect(
        ContentFilter.validate('shit', ContentFilterField.name),
        "That name isn't allowed on Hamme. Please choose another.",
      );
      expect(
        ContentFilter.validate('shit', ContentFilterField.username),
        "That username isn't allowed on Hamme. Please choose another.",
      );
      expect(
        ContentFilter.validate('shit', ContentFilterField.instagram),
        "That Instagram username isn't allowed on Hamme. Please choose another.",
      );
      expect(
        ContentFilter.validate('shit', ContentFilterField.snapchat),
        "That Snapchat username isn't allowed on Hamme. Please choose another.",
      );
    });
  });
}
