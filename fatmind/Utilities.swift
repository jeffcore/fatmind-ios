//
//  Utilities.swift
//  fatmind
//
//  Created by Rix on 4/21/16.
//  Copyright © 2016 bitcore. All rights reserved.
//

import Foundation


extension String
{
    func trim() -> String
    {
        return self.trimmingCharacters(in: CharacterSet.whitespaces)
    }
}


extension Int32 {
    
    func toBool () -> Bool {
        
        switch self {
        case 0:
            return false
        case 1:
            return true
        default:
            return true
        }
    }
}

