//
//  Constants.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/10/25.
//

import Foundation
import SwiftUI
import UIKit

struct ImageSymbolNames {
    static let checkmarkCircleFill = "checkmark.circle.fill"
    static let circle = "circle"
    static let cartFill = "cart.fill"
}

enum StoreCategory: String, CaseIterable {
    case preferred = "Preferred"
    case allStores = "All Stores"
    case generalMerchandise = "General Merchandise"
    case groceryAndFood = "Grocery & Food"
    case clothingAndApparel = "Clothing & Apparel"
    case electronics = "Electronics"
    case homeImprovement = "Home Improvement"
    case healthAndBeauty = "Health & Beauty"
    case specialtyStores = "Specialty Stores"
    
    // If you need the raw string value
    var displayName: String {
        return self.rawValue
    }
}

struct Constants {

    static let emptyString: String = ""
    
    static let isPremiumUserKey = "isPremiumUser"
    static let selectCategory = "Select Category"
    
    static let allStores = "All Stores"
    static let cancel = "Cancel"
    static let save = "Save"
    static let groceryAndFood = "Grocery & Food"
    static let generalMerchandise = "General Merchandise"
    
    // Dictionary of known store names to categories
    static let knownStoreCategories: [String: String] = [
        "home depot": "Hardware",
        "lowe's": "Hardware",
        "lowes": "Hardware",
        "ace hardware": "Hardware",
        "true value": "Hardware",
        "harbor freight": "Hardware",
        
        "walmart": "Department Store",
        "target": "Department Store",
        "kohl's": "Department Store",
        "macy's": "Department Store",
        "jcpenney": "Department Store",
        "dillard's": "Department Store",
        "nordstrom": "Department Store",
        
        "kroger": "Grocery",
        "publix": "Grocery",
        "whole foods": "Grocery",
        "safeway": "Grocery",
        "albertsons": "Grocery",
        "aldi": "Grocery",
        "trader joe's": "Grocery",
        "heb": "Grocery",
        "food lion": "Grocery",
        "wegmans": "Grocery",
        "giant": "Grocery",
        "stop & shop": "Grocery",
        "sprouts": "Grocery",
        
        "cvs": "Pharmacy",
        "walgreens": "Pharmacy",
        "rite aid": "Pharmacy",
        
        "costco": "Wholesale",
        "sam's club": "Wholesale",
        "bj's": "Wholesale",
        
        "best buy": "Electronics",
        "apple store": "Electronics",
        "microcenter": "Electronics",
        "gamestop": "Electronics",
        
        "petco": "Pets",
        "petsmart": "Pets",
        
        "ikea": "Home & Furniture",
        "ashley homestore": "Home & Furniture",
        "bed bath & beyond": "Home & Furniture",
        "crate & barrel": "Home & Furniture",
        "pottery barn": "Home & Furniture",
        
        "dollar tree": "Discount",
        "dollar general": "Discount",
        "family dollar": "Discount",
        "big lots": "Discount",
        
        "tj maxx": "Apparel",
        "marshalls": "Apparel",
        "ross": "Apparel",
        "burlington": "Apparel",
        "old navy": "Apparel",
        "gap": "Apparel",
        "foot locker": "Apparel"
    ]
    
    static let departments: [String] = ["Household Essentials & Cleaning",
                                        "Health & Wellness",
                                        "Beauty & Cosmetics",
                                        "Baby & Kids",
                                        "Clothing & Apparel",
                                        "Electronics & Office",
                                        "Home & Furniture",
                                        "Outdoor & Seasonal",
                                        "Automotive & Hardware",
                                        "Toys & Hobbies",
                                        "Sports & Outdoors",
                                        "Pets & Supplies",
                                        "Entertainment & Books",
                                        "Arts & Crafts",
                                        "Services"]
    
    static let departmentCategories: [String: [String]] = ["Grocery & Food": ["Fresh Produce",
                                                                              "Meat & Seafood",
                                                                              "Dairy & Eggs",
                                                                              "Bakery",
                                                                              "Deli & Prepared Foods",
                                                                              "Frozen Foods",
                                                                              "Snacks & Beverages",
                                                                              "Pantry Staples"]
    ]
    
    static let perishableCategories: [String] = ["Dairy",
                                                 "Eggs",
                                                 "Bakery",
                                                 "Meat & Poultry",
                                                 "Seafood",
                                                 "Meat & Seafood",
                                                 "Dairy & Eggs",
                                                 "Deli & Prepared Foods",
                                                 "Frozen Foods",
                                                 "Pantry Staples",
                                                 "Fresh Produce",
                                                 "Fruits",
                                                 "Vegetables",
                                                 "Prepared Foods"]
    
    static let expirationEstimates: [String: [String: [String: Int]]] = [
        "Fresh Produce": [
            "Fruits": [
                "Apples": 30,
                "Bananas": 7,
                "Oranges": 14,
                "Berries": 5,
                "Grapes": 7,
                "Melons": 7,
                "Pineapple": 7,
                "Mango": 7,
                "Peaches": 5,
                "Pears": 7
            ],
            "Vegetables": [
                "Lettuce": 7,
                "Spinach": 5,
                "Carrots": 21,
                "Broccoli": 7,
                "Cauliflower": 7,
                "Tomatoes": 7,
                "Cucumbers": 7,
                "Bell Peppers": 7,
                "Onions": 30,
                "Potatoes": 30
            ],
            "Herbs": [
                "Basil": 7,
                "Parsley": 7,
                "Cilantro": 7,
                "Mint": 7,
                "Rosemary": 14,
                "Thyme": 14
            ]
        ],
        "Dairy": [
            "Milk": [
                "Whole Milk": 7,
                "2% Milk": 7,
                "Skim Milk": 7,
                "Almond Milk": 7,
                "Soy Milk": 7,
                "Oat Milk": 7
            ],
            "Cheese": [
                "Cheddar": 30,
                "Mozzarella": 14,
                "Parmesan": 180,
                "Swiss": 30,
                "Brie": 14,
                "Feta": 30
            ],
            "Yogurt": [
                "Greek Yogurt": 14,
                "Regular Yogurt": 14,
                "Plant-based Yogurt": 14
            ],
            "Eggs": [
                "Chicken Eggs": 21,
                "Duck Eggs": 21
            ]
        ],
        "Meat": [
            "Beef": [
                "Ground Beef": 2,
                "Steak": 3,
                "Roast": 3
            ],
            "Pork": [
                "Pork Chops": 3,
                "Bacon": 7,
                "Ham": 7
            ],
            "Poultry": [
                "Chicken": 2,
                "Turkey": 2,
                "Duck": 2
            ],
            "Seafood": [
                "Fish": 2,
                "Shrimp": 2,
                "Crab": 2,
                "Lobster": 2
            ]
        ],
        "Bakery": [
            "Bread": [
                "White Bread": 7,
                "Whole Wheat": 7,
                "Sourdough": 7,
                "Baguette": 3
            ],
            "Pastries": [
                "Croissants": 3,
                "Muffins": 5,
                "Donuts": 3
            ],
            "Cakes": [
                "Birthday Cake": 5,
                "Cheesecake": 5
            ]
        ],
        "Frozen": [
            "Vegetables": [
                "Mixed Vegetables": 180,
                "Corn": 180,
                "Peas": 180
            ],
            "Fruits": [
                "Berries": 180,
                "Mango": 180,
                "Pineapple": 180
            ],
            "Meals": [
                "Pizza": 180,
                "TV Dinners": 180,
                "Ice Cream": 180
            ]
        ],
        "Canned": [
            "Vegetables": [
                "Corn": 365,
                "Green Beans": 365,
                "Peas": 365
            ],
            "Fruits": [
                "Pineapple": 365,
                "Peaches": 365,
                "Pears": 365
            ],
            "Soups": [
                "Chicken Noodle": 365,
                "Tomato": 365,
                "Vegetable": 365
            ]
        ],
        "Pantry": [
            "Grains": [
                "Rice": 180,
                "Pasta": 180,
                "Cereal": 180
            ],
            "Snacks": [
                "Crackers": 180,
                "Chips": 180,
                "Nuts": 180
            ],
            "Condiments": [
                "Ketchup": 180,
                "Mustard": 180,
                "Mayonnaise": 180
            ]
        ],
        "Beverages": [
            "Juices": [
                "Orange Juice": 7,
                "Apple Juice": 7,
                "Cranberry Juice": 7
            ],
            "Soda": [
                "Cola": 180,
                "Lemon-lime": 180,
                "Root Beer": 180
            ],
            "Water": [
                "Bottled Water": 365,
                "Sparkling Water": 180
            ]
        ]
    ]

    // Helper function to get default expiration days for a category
    static func getDefaultExpirationDays(for category: String) -> Int? {
        // Return a default value for the category if no specific item is found
        switch category {
        case "Fresh Produce": return 7
        case "Dairy": return 7
        case "Meat": return 3
        case "Bakery": return 7
        case "Frozen": return 180
        case "Canned": return 365
        case "Pantry": return 180
        case "Beverages": return 180
        default: return nil
        }
    }
    
    // ✅ Shopping Category Icons
    static let groceryFoodCategoryIcons: [String: String] = [
        "Fresh Produce": "🍉",
        "Meat & Seafood": "🐟",
        "Dairy & Eggs": "🧀",
        "Bakery": "🍩",
        "Deli & Prepared Foods": "🥗",
        "Frozen Foods": "🍦",
        "Snacks & Beverages": "🥨",
        "Pantry Staples": "🥫"
    ]
    
    static let shoppingCategoryIcons: [String: String] = [
        "Household Essentials & Cleaning": "🧽",
        "Health & Wellness": "❤️‍🩹",
        "Beauty & Cosmetics": "💄",
        "Baby & Kids": "🍼",
        "Clothing & Apparel": "🧥",
        "Electronics & Office": "📱",
        "Home & Furniture": "🛋️",
        "Outdoor & Seasonal": "♨️",
        "Automotive & Hardware": "🚙",
        "Toys & Hobbies": "🚂",
        "Sports & Outdoors": "🏈",
        "Pets & Supplies": "🐶",
        "Entertainment & Books": "📚",
        "Arts & Crafts": "🎨",
        "Services": "👨🏻‍🔧",
    ]
    
    // ✅ Shopping Category Colors
     static let shoppingCategoryColors: [String: Color] = [
        "Grocery & Food": Color(hex: "FFD300"),
        "Household Essentials & Cleaning": Color(hex: "FFAA00"),
        "Health & Wellness": Color(hex: "FFD300"),
        "Beauty & Cosmetics": Color(hex: "FFAA00"),
        "Baby & Kids": Color(hex: "FFD300"),
        "Clothing & Apparel": Color(hex: "FFAA00"),
        "Electronics & Office": Color(hex: "FFD300"),
        "Home & Furniture": Color(hex: "FFAA00"),
        "Outdoor & Seasonal": Color(hex: "FFD300"),
        "Automotive & Hardware": Color(hex: "FFAA00"),
        "Toys & Hobbies": Color(hex: "FFD300"),
        "Sports & Outdoors": Color(hex: "FFAA00"),
        "Pets & Supplies": Color(hex: "FFD300"),
        "Entertainment & Books": Color(hex: "FFAA00"),
        "Arts & Crafts": Color(hex: "FFD300"),
        "Services": Color(hex: "FFAA00")
    ]
    
    static let toDoCategories: [String: [String]] = ["Personal & Daily Tasks": ["Appointments",
                                                                                "Exercise",
                                                                                "Hobbies & Interests",
                                                                                "Self-Care",
                                                                                "Finance & Budgeting"],
                                                     "Work & Productivity": ["Meetings",
                                                                             "Projects",
                                                                             "Deadlines",
                                                                             "Networking"],
                                                     "Errands & Chores": ["Bills & Payments",
                                                                          "Cleaning",
                                                                          "Car Maintenance",
                                                                          "Home Repairs"],
                                                     "Family & Social": ["Birthdays",
                                                                         "Events",
                                                                         "Parenting",
                                                                         "Volunteering"],
                                                     "Health & Wellness": ["Doctor Visits",
                                                                           "Medication Reminders",
                                                                           "Mental Health"],
                                                     "Travel & Leisure": ["Trip Planning",
                                                                          "Vacation Prep",
                                                                          "Packing List"],
                                                     "Custom": [""]
                                                    ]

    static let toDoCategoryIcons: [String: String] = [
        "Appointments": "calendar",
        "Exercise": "figure.walk",
        "Hobbies & Interests": "paintpalette",
        "Self-Care": "heart.fill",
        "Finance & Budgeting": "dollarsign.circle.fill",
        "Meetings": "person.2.fill",
        "Projects": "folder.fill",
        "Deadlines": "clock.fill",
        "Networking": "person.crop.circle.badge.plus",
        "Bills & Payments": "creditcard.fill",
        "Cleaning": "robotic.vacuum.fill",
        "Car Maintenance": "car.fill",
        "Home Repairs": "house.fill",
        "Birthdays": "gift.fill",
        "Events": "calendar.badge.clock",
        "Parenting": "person.3.fill",
        "Volunteering": "hands.clap.fill",
        "Doctor Visits": "stethoscope",
        "Medication Reminders": "pills.fill",
        "Mental Health": "brain.head.profile",
        "Trip Planning": "airplane",
        "Vacation Prep": "suitcase.fill",
        "Packing List": "list.bullet",
        "Custom": "plus.circle"
    ]

    static let toDoCategoryColors: [String: Color] = [
        "Appointments": .blue,
        "Exercise": .green,
        "Hobbies & Interests": .orange,
        "Self-Care": .pink,
        "Finance & Budgeting": .purple,
        "Meetings": .blue,
        "Projects": .yellow,
        "Deadlines": .red,
        "Networking": .cyan,
        "Bills & Payments": .teal,
        "Cleaning": .brown,
        "Car Maintenance": .gray,
        "Home Repairs": .indigo,
        "Birthdays": .purple,
        "Events": .mint,
        "Parenting": .green,
        "Volunteering": .pink,
        "Doctor Visits": .red,
        "Medication Reminders": .purple,
        "Mental Health": .teal,
        "Trip Planning": .blue,
        "Vacation Prep": .cyan,
        "Packing List": .gray,
        "Custom": .gray
    ]
}

func categorizeProduct(from category: String?) -> String {
    let categoryMappings: [String: String] = [
        // ✅ Canned Goods (Mapped to Pantry Staples)
        "canned soup": "Grocery -> Pantry Staples",
        "canned soups": "Grocery -> Pantry Staples",
        "cream of mushroom soup": "Grocery -> Pantry Staples",
        "tomato soup": "Grocery -> Pantry Staples",
        "chicken noodle soup": "Grocery -> Pantry Staples",
        "canned goods": "Grocery -> Pantry Staples",
        "canned vegetables": "Grocery -> Pantry Staples",
        "peas": "Grocery -> Pantry Staples",
        "chick peas": "Grocery -> Pantry Staples",
        "garbanzo": "Grocery -> Pantry Staples",
        "canned beans": "Grocery -> Pantry Staples",
        "black beans": "Grocery -> Pantry Staples",
        "kidney beans": "Grocery -> Pantry Staples",
        "lentils": "Grocery -> Pantry Staples",
        "corn": "Grocery -> Pantry Staples",
        "mushroom": "Grocery -> Pantry Staples",

        // ✅ Vitamins & Supplements
        "vitamin": "Health & Wellness -> Vitamins & Supplements",
        "supplement": "Health & Wellness -> Vitamins & Supplements",

        // ✅ Personal Care
        "shampoo": "Personal Care -> Hair Care",
        "conditioner": "Personal Care -> Hair Care",
        "toothpaste": "Personal Care -> Oral Care",
        "deodorant": "Personal Care -> Hygiene",

        // ✅ Beverages & Dairy
        "coffee": "Grocery -> Beverages",
        "tea": "Grocery -> Beverages",
        "milk": "Grocery -> Dairy",
        "cheese": "Grocery -> Dairy",
        "yogurt": "Grocery -> Dairy",

        // ✅ Meat & Seafood
        "chicken": "Grocery -> Meat & Poultry",
        "beef": "Grocery -> Meat & Poultry",
        "fish": "Grocery -> Seafood",

        // ✅ Bakery
        "bread": "Grocery -> Bakery",

        // ✅ Snacks
        "snack": "Grocery -> Snacks",
        "chips": "Grocery -> Snacks",
        "cereal": "Grocery -> Breakfast",

        // ✅ Miscellaneous (Default Fallback)
        "miscellaneous": "Miscellaneous"
    ]

    guard let category = category?.lowercased(), !category.isEmpty else {
        return "Miscellaneous" // ✅ Default if category is missing
    }

    // ✅ Check for keyword matches in categoryMappings keys
    for (keyword, mappedCategory) in categoryMappings {
        if category.contains(keyword) {
            return mappedCategory // ✅ Return correct category
        }
    }

    return "Miscellaneous" // ✅ Fallback category if no match found
}

func determineBarcodeCategory(for productName: String, apiCategory: String?) -> String {
    let lowercasedName = productName.lowercased()
    
    print("🔍 DEBUG: Determining category for - Name: \(productName), API Category: \(apiCategory ?? "None")")

    // ✅ 1. Use `categorizeProduct` for product name-based mappings (HIGHEST PRIORITY)
    let mappedCategory = categorizeProduct(from: productName)
    if mappedCategory != "Miscellaneous" {
        print("✅ Mapped product name keyword to category: \(mappedCategory)")
        return mappedCategory
    }

    // ✅ 2. If the product name didn’t match, try API category mapping
    if let apiCategory = apiCategory {
        let mappedFromAPI = categorizeProduct(from: apiCategory)
        if mappedFromAPI != "Miscellaneous" {
            print("✅ Mapped API Category to: \(mappedFromAPI)")
            return mappedFromAPI
        }
    }

    print("⚠️ No match found, returning 'Miscellaneous'")
    return "Miscellaneous"
}

enum ShoppingNotification: String {
    case shoppingListUpdated = "ShoppingListUpdated"
    case fetchShoppingItemsOnce = "FetchShoppingItemsOnce"
    case forceUIRefreshAfterSave = "ForceUIRefreshAfterSave"
    case shoppingItemDeleted = "ShoppingItemDeleted"
    case shoppingItemCompleted = "ShoppingItemCompleted"
    case stopContinuousFetching = "StopContinuousFetching"
    case forceUIRefresh = "ForceUIRefresh"

    var name: Notification.Name {
        Notification.Name(self.rawValue)
    }
}

enum ToDoNotification: String {
    case todoCategoriesUpdated = "ToDoCategoriesUpdated"

    var name: Notification.Name {
        Notification.Name(self.rawValue)
    }
}
