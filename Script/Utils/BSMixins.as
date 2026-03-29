mixin FRotator MaskYaw (FRotator Self)
{
	return FRotator(0, Self.Yaw, 0);
}