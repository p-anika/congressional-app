import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:congressional_app/models/rescue_request.dart';
import 'package:congressional_app/services/rescue_service.dart';
import 'package:congressional_app/widgets/delivery_instructions_sheet.dart';
import 'package:congressional_app/widgets/rescue_request_widgets.dart';

// Seeded data — no Firebase; streams are injected.
const helperUid = 'helper-1';
const recipientUid = 'recipient-1';

RescueRequest seed(String status, {String? helperId = helperUid}) => RescueRequest(
      id: 'req-1',
      code: '1234',
      listingId: 'listing-1',
      claimId: 'claim-1',
      restaurantId: 'rest-1',
      restaurantName: 'Mario\'s Pizza',
      restaurantAddress: '12 Main St, Springfield',
      restaurantLat: 37.77,
      restaurantLng: -122.41,
      item: 'Margherita slices',
      quantity: 2,
      recipientId: recipientUid,
      helperId: helperId,
      status: status,
      approxLat: 37.78,
      approxLng: -122.42,
    );

final dropoff = RescueDropoff(
  address: '55 Oak Ave, Springfield',
  lat: 37.781,
  lng: -122.423,
  notes: 'Apt 3, buzzer 12',
);

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Future<void> openSheet(WidgetTester tester, RescueRequest r) async {
  await tester.pumpWidget(host(VolunteerRescueCard(
    request: r,
    uid: helperUid,
    requestStream: Stream.value(r),
    dropoffStream: Stream.value(dropoff),
  )));
  await tester.tap(find.text('Delivery instructions'));
  await tester.pumpAndSettle();
}

void main() {
  group('Volunteer card', () {
    testWidgets('open request shows Accept and hides address', (tester) async {
      await tester.pumpWidget(host(VolunteerRescueCard(
          request: seed(RescueStatus.open, helperId: null), uid: helperUid)));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget); // status chip
      expect(find.text('Delivery instructions'), findsNothing);
      expect(find.textContaining('exact address shown after you accept'),
          findsOneWidget);
      expect(find.textContaining('55 Oak Ave'), findsNothing);
    });

    testWidgets('claimed shows Picked up + instructions', (tester) async {
      await tester.pumpWidget(
          host(VolunteerRescueCard(request: seed(RescueStatus.claimed), uid: helperUid)));
      expect(find.text('Picked up'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Delivery instructions'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('awaiting restaurant shows no action button', (tester) async {
      await tester.pumpWidget(host(VolunteerRescueCard(
          request: seed(RescueStatus.pickupPendingRestaurant), uid: helperUid)));
      expect(find.text('Picked up'), findsNothing);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('Awaiting restaurant'), findsOneWidget);
    });

    testWidgets('picked up shows Delivered', (tester) async {
      await tester.pumpWidget(
          host(VolunteerRescueCard(request: seed(RescueStatus.pickedUp), uid: helperUid)));
      expect(find.text('Delivered'), findsOneWidget);
    });
  });

  group('Delivery instructions sheet', () {
    testWidgets('step 1 before pickup, directions to restaurant', (tester) async {
      await openSheet(tester, seed(RescueStatus.claimed));
      expect(find.text('Delivery instructions · #1234'), findsOneWidget);
      expect(find.text('Step 1: Pick up the food'), findsOneWidget);
      expect(
          find.textContaining(
              'Go to Mario\'s Pizza at 12 Main St, Springfield. Tell staff '
              'you\'re picking up request #1234'),
          findsOneWidget);
      expect(find.textContaining('Tap "Picked up" once you have the food.'),
          findsOneWidget);
      expect(find.text('Get directions to Mario\'s Pizza'), findsOneWidget);
      expect(find.text('Get directions to recipient'), findsNothing);
    });

    testWidgets('step 2 waiting for restaurant', (tester) async {
      await openSheet(tester, seed(RescueStatus.pickupPendingRestaurant));
      expect(
          find.descendant(
              of: find.byType(DeliveryInstructions),
              matching: find.textContaining(
                  'Waiting for Mario\'s Pizza to confirm the handoff')),
          findsOneWidget);
      expect(find.text('Get directions to Mario\'s Pizza'), findsOneWidget);
    });

    testWidgets('step 3 after pickup shows address, notes, recipient directions',
        (tester) async {
      await openSheet(tester, seed(RescueStatus.pickedUp));
      expect(
          find.textContaining('Deliver to 55 Oak Ave, Springfield. '
              'Notes: Apt 3, buzzer 12. Tap "Delivered" when done.'),
          findsOneWidget);
      expect(find.text('Get directions to recipient'), findsOneWidget);
      expect(find.text('Get directions to Mario\'s Pizza'), findsNothing);
    });

    testWidgets('after delivered shows waiting for recipient', (tester) async {
      await openSheet(tester, seed(RescueStatus.deliveredPendingRecipient));
      expect(find.textContaining('Waiting for the recipient to confirm'),
          findsWidgets);
      expect(find.textContaining('Get directions'), findsNothing);
    });
  });

  testWidgets('Restaurant sees pending handoff with both buttons', (tester) async {
    await tester.pumpWidget(host(RestaurantRescueHandoffs(
      restaurantId: 'rest-1',
      listingId: 'listing-1',
      stream: Stream.value([seed(RescueStatus.pickupPendingRestaurant)]),
    )));
    await tester.pump();
    expect(find.text('Volunteer pickups to confirm:'), findsOneWidget);
    expect(find.text('Request #1234 · 2 portions'), findsOneWidget);
    expect(find.text('Confirm handoff'), findsOneWidget);
    expect(find.text('Didn\'t happen'), findsOneWidget);
  });

  testWidgets('Recipient sees Received / Didn\'t receive once delivered',
      (tester) async {
    await tester.pumpWidget(host(RecipientRescueRequests(
      uid: recipientUid,
      stream: Stream.value([seed(RescueStatus.deliveredPendingRecipient)]),
    )));
    await tester.pump();
    expect(find.text('Delivered — please confirm'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Didn\'t receive'), findsOneWidget);
  });

  testWidgets('Recipient delivery popup renders and validates', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showRescueDeliveryPopup(context,
              itemName: 'Margherita slices', quantity: 2, onSubmit: (_) async {}),
          child: const Text('Request Delivery'),
        ),
      ),
    ));
    await tester.tap(find.text('Request Delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Where should we deliver?'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);

    await tester.tap(find.text('Request'));
    await tester.pump();
    expect(find.text('Enter a delivery address or use your current location.'),
        findsOneWidget);
  });

  group('Address without coordinates', () {
    const typed = '305 211th PL SE, Sammamish, WA 98074, USA';

    testWidgets('popup still creates the request when geocoding fails',
        (tester) async {
      RescueDropoff? saved;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showRescueDeliveryPopup(context,
                itemName: 'Margherita slices',
                quantity: 2,
                onSubmit: (d) async => saved = d),
            child: const Text('Request Delivery'),
          ),
        ),
      ));
      await tester.tap(find.text('Request Delivery'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Delivery address'), typed);
      await tester.enterText(find.widgetWithText(TextField, 'Notes (optional)'), 'Apt 3');
      // flutter_test blocks real HTTP, so the geocode call fails here —
      // exactly the failure case we want to cover.
      await tester.runAsync(() async {
        await tester.tap(find.text('Request'));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.address, typed);
      expect(saved!.notes, 'Apt 3');
      expect(saved!.hasCoordinates, isFalse);
      expect(find.text('Where should we deliver?'), findsNothing); // closed
      expect(find.textContaining('Couldn\'t find'), findsNothing);
    });

    test('directions use lat/lng when present', () {
      final uri = RescueService.directionsUri(lat: 47.6, lng: -122.05, address: typed);
      expect(uri.toString(),
          'https://www.google.com/maps/dir/?api=1&destination=47.6%2C-122.05');
    });

    test('directions fall back to the address text', () {
      final uri = RescueService.directionsUri(address: typed);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], typed);
      expect(uri.toString(), contains('305+211th+PL+SE%2C+Sammamish'));
      final apple = RescueService.directionsUri(address: typed, apple: true);
      expect(apple.queryParameters['daddr'], typed);
    });

    test('0,0 restaurant coordinates fall back to the address', () {
      final uri = RescueService.directionsUri(
          lat: 0, lng: 0, address: '12 Main St, Springfield');
      expect(uri.queryParameters['destination'], '12 Main St, Springfield');
    });

    testWidgets('sheet + card render with no drop-off coordinates', (tester) async {
      final r = RescueRequest(
        id: 'req-2', code: '5678', listingId: 'l', claimId: 'c',
        restaurantId: 'rest-1', restaurantName: 'Mario\'s Pizza',
        restaurantAddress: '12 Main St, Springfield',
        restaurantLat: 37.77, restaurantLng: -122.41,
        item: 'Soup', quantity: 1, recipientId: recipientUid,
        helperId: helperUid, status: RescueStatus.pickedUp,
        // approxLat/approxLng omitted: address wasn't geocoded
      );
      await tester.pumpWidget(host(VolunteerRescueCard(
        request: r,
        uid: helperUid,
        requestStream: Stream.value(r),
        dropoffStream: Stream.value(RescueDropoff(address: typed, notes: 'Apt 3')),
      )));
      await tester.tap(find.text('Delivery instructions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Deliver to $typed. Notes: Apt 3.'), findsOneWidget);
      expect(find.text('Get directions to recipient'), findsOneWidget);
    });

    testWidgets('open card renders with no approx coordinates', (tester) async {
      final r = RescueRequest(
        id: 'req-3', code: '9999', listingId: 'l', claimId: 'c',
        restaurantId: 'rest-1', restaurantName: 'Mario\'s Pizza',
        restaurantAddress: '12 Main St', restaurantLat: 37.77, restaurantLng: -122.41,
        item: 'Soup', quantity: 1, recipientId: recipientUid,
        status: RescueStatus.open,
      );
      await tester.pumpWidget(host(VolunteerRescueCard(request: r, uid: helperUid)));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('exact address shown after you accept'), findsOneWidget);
    });
  });
}
