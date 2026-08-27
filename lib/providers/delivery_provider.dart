import 'package:flutter/material.dart';
import '../models/delivery_request.dart';
import '../models/food_listing.dart';
import '../services/firebase_service.dart';

class DeliveryProvider extends ChangeNotifier {
  Future<void> requestDelivery({
    required FoodListing listing,
    required String userId,
    required int quantity,
    required double userLat,
    required double userLng,
    String? userPhone,
  }) {
    return FirebaseService.requestDelivery(
      listing: listing,
      userId: userId,
      quantity: quantity,
      userLat: userLat,
      userLng: userLng,
      userPhone: userPhone,
    );
  }

  Stream<List<DeliveryRequest>> pendingDeliveryRequests() =>
      FirebaseService.pendingDeliveryRequestsStream();

  Stream<List<DeliveryRequest>> myAcceptedDeliveries(String volunteerId) =>
      FirebaseService.volunteerDeliveriesStream(volunteerId);

  Stream<List<DeliveryRequest>> myRequestedDeliveries(String userId) =>
      FirebaseService.userDeliveryRequestsStream(userId);
      
  Stream<List<DeliveryRequest>> deliveryHistory(String volunteerId) =>
      FirebaseService.volunteerDeliveryHistoryStream(volunteerId);

  Future<void> acceptDelivery(String requestId, String volunteerId) =>
      FirebaseService.acceptDeliveryRequest(requestId, volunteerId);

  Future<void> completeDelivery(String requestId) =>
      FirebaseService.completeDelivery(requestId);

  Future<void> cancelDeliveryRequest(String requestId) =>
      FirebaseService.cancelDeliveryRequest(requestId);
}