export type FleetDeliveryCommand = {
  args: string[];
  executable: string;
};

export function resolveFleetDeliveryCommand(
  filePath: string,
  timestamp: string,
): FleetDeliveryCommand {
  return {
    executable: "fleet",
    args: [
      "mac",
      "put",
      "--open",
      filePath,
      `/tmp/session-viewer-${timestamp}`,
    ],
  };
}
