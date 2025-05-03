public class PricingService extends commercestorepricing.PricingService {
    
  private static String externalPricingServiceHost;
  
  static {
      List<ExternalServiceConfig__mdt> configs = [SELECT ServiceURL__c FROM ExternalServiceConfig__mdt WHERE DeveloperName = 'ServiceURL_Mock' LIMIT 1];
      if (!configs.isEmpty()) {
          externalPricingServiceHost = configs[0].ServiceURL__c;
      } else {
          throw new CalloutException('A URL do serviço externo não está configurada.');
      }
  }
  
  private static Boolean useExternalService = true;
  
  public override commercestorepricing.PricingResponse processPrice(commercestorepricing.PricingRequest request) {
      
      Set<String> products = new Set<String>();
      commercestorepricing.PricingRequestItemCollection items = request.getPricingRequestItems();
      for (Integer i = 0; i < items.size(); i++) {
          commercestorepricing.PricingRequestItem item = items.get(i);
          products.add(item.getProductId());
      }
      Map<String, PriceDataFromExternalService> pricesFromExternalService;
      
      if (useExternalService) {
          pricesFromExternalService = getPricesFromExternalService(products);
      }
      
      commercestorepricing.PricingResponse response = new commercestorepricing.PricingResponse('USD');
      for (Integer i = 0; i < items.size(); i++) {
          String productId = items.get(i).getProductId();
          
          PriceDataFromExternalService dataFromExternalService = pricesFromExternalService.get(productId);
          commercestorepricing.PricingResponseItem responseItem = new commercestorepricing.PricingResponseItem(
              productId,
              null,
              null,
              dataFromExternalService.getPrice(), // Use the single price
              dataFromExternalService.getPrice()  // Use the same price for both list and unit price
          );
          response.addPricingResponseItem(responseItem);
          
      }
      
      return response;
  }
  
  public override commercestorepricing.TransactionalPricingResponse processTransactionalPrice(commercestorepricing.TransactionalPricingRequest request2) {
      commercestorepricing.TransactionalPricingRequestItem reqItem = request2.getTxnPricingRequestItems().get(0);
      reqItem.setQuantity(reqItem.getQuantity() + 1);
      
      commercestorepricing.TransactionalPricingResponse txnResponse = super.processTransactionalPrice(request2);
      
      String prefix = 'XYZ_';
      Decimal fixedAdjustmentAmount = 5;
      commercestorepricing.TxnPricingResponseItemCollection txnItemCollection = txnResponse.getTxnPricingResponseItems();
      for (Integer j = 0; j < txnItemCollection.size(); j++) {
          commercestorepricing.TransactionalPricingResponseItem txnItem = txnItemCollection.get(j);
          txnItem.setLineId(appendField(prefix, txnItem.getLineId()));
          txnItem.setProductId(appendField(prefix, txnItem.getProductId()));
          txnItem.setUnitPricePriceBookEntryId(appendField(prefix, txnItem.getUnitPricePriceBookEntryId()));
          txnItem.setTotalAdjustmentAmount(txnItem.getTotalAdjustmentAmount() - fixedAdjustmentAmount);
          txnItem.setTotalPrice(txnItem.getTotalPrice() - fixedAdjustmentAmount);
      }
      txnResponse.setTotalAdjustmentAmount(txnResponse.getTotalAdjustmentAmount() - (fixedAdjustmentAmount * txnItemCollection.size()));
      txnResponse.setTotalAmount(txnResponse.getTotalProductAmount() + txnResponse.getTotalAdjustmentAmount());
      
      if (!txnItemCollection.isEmpty()) {
          String customErrorMessage = 'We no longer sell this particular product.';
          String localizedErrorMessage = 'Wir verkaufen dieses spezielle Produkt nicht mehr.';
          txnItemCollection.get(0).setError(customErrorMessage, localizedErrorMessage);
      }
      return txnResponse;
  }
  
    private Map<String, PriceDataFromExternalService> populatePrice(Map<String, Object> skuPrices) {
        Map<String, PriceDataFromExternalService> priceDataFromExternalServiceBySKU = new Map<String, PriceDataFromExternalService>();
        for (String sku : skuPrices.keySet()) {
            Map<String, Object> pricesFromExternalService = (Map<String, Object>) skuPrices.get(sku);
            priceDataFromExternalServiceBySKU.put(sku, new PriceDataFromExternalService(price));
        }
        return priceDataFromExternalServiceBySKU;
    }
  
    private Map<String, PriceDataFromExternalService> getPricesFromExternalService(Set<String> productIds) {
        Map<String, String> productIdToSKUMap = new Map<String, String>();
        List<Product2> products = [SELECT Id, StockKeepingUnit FROM Product2 WHERE Id IN :productIds];
        for (Product2 product : products) {
            productIdToSKUMap.put(product.Id, product.StockKeepingUnit);
        }
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        Integer SuccessfulHttpRequest = 200;
        
        String requestURL = externalPricingServiceHost;
        request.setEndpoint(requestURL);
        request.setMethod('GET');
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == SuccessfulHttpRequest) {
            Map<String, Object> resultsFromExternalService = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    
            return populatePrice(resultsFromExternalService);
        } else {
            throw new CalloutException('There was a problem with the request. Error: ' + response.getStatusCode());
        }
    }
  
  @TestVisible
  private String appendField(String prefix, String field) {
      return prefix + field;
  }
  
  class PriceDataFromExternalService {
      private Decimal price; // Single price for each SKU
      
      public PriceDataFromExternalService() {
          price = 0.0;
      }
      
      public PriceDataFromExternalService(Decimal inputPrice) {
          price = inputPrice;
      }
      
      public Decimal getPrice() {
          return price;
      }
  }
}