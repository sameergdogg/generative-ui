package com.generativeui.dsl.render

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight

fun resolveColor(name: String?): Color? {
    if (name == null) return null
    return when (name.lowercase()) {
        "red" -> Color(0xFFFF3B30)
        "blue" -> Color(0xFF007AFF)
        "green" -> Color(0xFF34C759)
        "orange" -> Color(0xFFFF9500)
        "purple" -> Color(0xFFAF52DE)
        "pink" -> Color(0xFFFF2D55)
        "yellow" -> Color(0xFFFFCC00)
        "gray", "grey" -> Color(0xFF8E8E93)
        "brown" -> Color(0xFFA2845E)
        "cyan" -> Color(0xFF32ADE6)
        "mint" -> Color(0xFF00C7BE)
        "teal" -> Color(0xFF30B0C7)
        "indigo" -> Color(0xFF5856D6)
        "white" -> Color.White
        "black" -> Color.Black
        else -> null
    }
}

@Composable
fun resolveColorWithTheme(name: String?): Color {
    if (name == null) return MaterialTheme.colorScheme.onSurface
    return resolveColor(name)
        ?: when (name.lowercase()) {
            "primary" -> MaterialTheme.colorScheme.onSurface
            "secondary" -> MaterialTheme.colorScheme.onSurfaceVariant
            else -> MaterialTheme.colorScheme.onSurface
        }
}

@Composable
fun resolveTextStyle(style: String?): TextStyle {
    return when (style) {
        "largeTitle" -> MaterialTheme.typography.displaySmall
        "title" -> MaterialTheme.typography.headlineLarge
        "title2" -> MaterialTheme.typography.headlineMedium
        "title3" -> MaterialTheme.typography.headlineSmall
        "headline" -> MaterialTheme.typography.titleMedium
        "subheadline" -> MaterialTheme.typography.titleSmall
        "body" -> MaterialTheme.typography.bodyLarge
        "caption" -> MaterialTheme.typography.labelSmall
        "caption2" -> MaterialTheme.typography.labelSmall
        "footnote" -> MaterialTheme.typography.bodySmall
        else -> MaterialTheme.typography.bodyLarge
    }
}

fun resolveFontWeight(weight: String?): FontWeight {
    return when (weight) {
        "ultraLight" -> FontWeight.ExtraLight
        "thin" -> FontWeight.Thin
        "light" -> FontWeight.Light
        "regular" -> FontWeight.Normal
        "medium" -> FontWeight.Medium
        "semibold" -> FontWeight.SemiBold
        "bold" -> FontWeight.Bold
        "heavy" -> FontWeight.ExtraBold
        "black" -> FontWeight.Black
        else -> FontWeight.Normal
    }
}

private val iconMap: Map<String, ImageVector> = mapOf(
    "dollarsign.circle" to Icons.Filled.AttachMoney,
    "dollarsign.circle.fill" to Icons.Filled.AttachMoney,
    "cart.fill" to Icons.Filled.ShoppingCart,
    "cart" to Icons.Filled.ShoppingCart,
    "fork.knife" to Icons.Filled.Restaurant,
    "list.bullet" to Icons.Filled.FormatListBulleted,
    "star" to Icons.Filled.Star,
    "star.fill" to Icons.Filled.Star,
    "heart.fill" to Icons.Filled.Favorite,
    "heart" to Icons.Filled.FavoriteBorder,
    "house.fill" to Icons.Filled.Home,
    "house" to Icons.Filled.Home,
    "gear" to Icons.Filled.Settings,
    "gearshape" to Icons.Filled.Settings,
    "person.fill" to Icons.Filled.Person,
    "person" to Icons.Filled.Person,
    "bell.fill" to Icons.Filled.Notifications,
    "bell" to Icons.Filled.Notifications,
    "magnifyingglass" to Icons.Filled.Search,
    "checkmark.circle.fill" to Icons.Filled.CheckCircle,
    "checkmark.circle" to Icons.Filled.CheckCircle,
    "xmark.circle.fill" to Icons.Filled.Cancel,
    "xmark.circle" to Icons.Filled.Cancel,
    "exclamationmark.triangle.fill" to Icons.Filled.Warning,
    "exclamationmark.triangle" to Icons.Filled.Warning,
    "info.circle.fill" to Icons.Filled.Info,
    "info.circle" to Icons.Filled.Info,
    "arrow.up.right" to Icons.Filled.TrendingUp,
    "arrow.down.right" to Icons.Filled.TrendingDown,
    "arrow.right" to Icons.Filled.ArrowForward,
    "arrow.left" to Icons.Filled.ArrowBack,
    "mappin.and.ellipse" to Icons.Filled.LocationOn,
    "envelope.fill" to Icons.Filled.Email,
    "envelope" to Icons.Filled.Email,
    "phone.fill" to Icons.Filled.Phone,
    "phone" to Icons.Filled.Phone,
    "calendar" to Icons.Filled.CalendarToday,
    "clock.fill" to Icons.Filled.Schedule,
    "clock" to Icons.Filled.Schedule,
    "creditcard.fill" to Icons.Filled.CreditCard,
    "creditcard" to Icons.Filled.CreditCard,
    "tag.fill" to Icons.Filled.LocalOffer,
    "tag" to Icons.Filled.LocalOffer,
    "fuelpump.fill" to Icons.Filled.LocalGasStation,
    "fuelpump" to Icons.Filled.LocalGasStation,
    "car.fill" to Icons.Filled.DirectionsCar,
    "car" to Icons.Filled.DirectionsCar,
)

fun resolveIcon(sfSymbolName: String): ImageVector {
    return iconMap[sfSymbolName] ?: Icons.Filled.HelpOutline
}
