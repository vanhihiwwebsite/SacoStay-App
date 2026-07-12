/// Nav link definitions shared by navbar and discovery overlay.
class NavLinkItem {
  const NavLinkItem({
    required this.name,
    required this.path,
    required this.roles,
    this.iconAsset,
  });

  final String name;
  final String path;
  final List<String> roles;
  final String? iconAsset;
}
