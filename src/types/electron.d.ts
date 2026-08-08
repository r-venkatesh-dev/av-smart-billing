export {};

declare global {
  interface Window {
    avSmartbillingDesktop?: {
      readonly isDesktop: true;
      getDeviceIdentity(): Promise<{ fingerprint: string; deviceName: string }>;
    };
  }
}
